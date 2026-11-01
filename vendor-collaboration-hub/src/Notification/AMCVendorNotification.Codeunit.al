namespace Addmecode.VendorCollaborationHub;

using Microsoft.CRM.Team;
using Microsoft.Foundation.Reporting;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Email;
using System.Utilities;

/// <summary>
/// Prepares vendor notifications, issues access links and hands email to the configured email scenario.
/// </summary>
codeunit 50118 "AMC Vendor Notification"
{
  Permissions = tabledata "AMC Vendor Access Token" = rm,
                tabledata "AMC Vendor Request" = r,
                tabledata "Purchase Header" = r,
                tabledata "Salesperson/Purchaser" = r,
                tabledata Vendor = r;

  /// <summary>
  /// Issues a token, prepares and hands off its email, then stamps successful delivery metadata; handoff failures raise an error.
  /// Standard email handoff can commit; this procedure does not promise transactional delivery.
  /// </summary>
  /// <param name="RequestNo">The request for which a new bearer link is issued.</param>
  [NonDebuggable]
  procedure Send(RequestNo: Code[20])
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessTokenMgt: Codeunit "AMC Access Token Mgt";
    CollabLog: Codeunit "AMC Collab Log";
    Email: Codeunit Email;
    EmailMessage: Codeunit "Email Message";
    Telemetry: Codeunit "AMC Telemetry";
    AccessLink: Text;
    LastErrorText: Text;
    Recipient: Text;
    RawToken: Text;
    EmailWasSent: Boolean;
    IsHandled: Boolean;
    LinkSendFailedErr: Label 'The vendor access link email could not be sent: %1', Comment = '%1 = original error detail';
  begin
    if not VendorRequest.Get(RequestNo) then
      Error(this.RequiredRecordNotFoundErr, VendorRequest.TableCaption());
    Recipient := this.GetRecipient(VendorRequest);

    RawToken := AccessTokenMgt.Issue(RequestNo);
    AccessLink := this.CreateAccessLink(VendorRequest, RawToken);
    this.Prepare(VendorRequest, AccessLink, EmailMessage);
    this.OnSendOnBeforeEmailSend(RequestNo, Enum::"Email Scenario"::"AMC Vendor Collaboration", IsHandled, EmailWasSent);
    if not IsHandled then
      EmailWasSent := this.TrySend(Email, EmailMessage);
    if not EmailWasSent then begin
      LastErrorText := GetLastErrorText();
      if LastErrorText = '' then
        LastErrorText := this.EmailNotSentErr;
      CollabLog.LogEvent("AMC Source Type"::Request, VendorRequest."No.", 0, "AMC Collab Entry Type"::LinkSendFailed, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), CopyStr(LastErrorText, 1, 250), CreateGuid());
      Telemetry.LogLinkSendFailed(VendorRequest."No.", VendorRequest."Vendor No.", VendorRequest."Purchase Order No.");
      Error(LinkSendFailedErr, LastErrorText);
    end;

    this.StampTokenSent(AccessTokenMgt.HashToken(RawToken), Recipient);
    CollabLog.LogEvent("AMC Source Type"::Request, VendorRequest."No.", 0, "AMC Collab Entry Type"::LinkSent, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), this.LinkSentDescriptionLbl, CreateGuid());
    Telemetry.LogLinkSent(VendorRequest."No.", VendorRequest."Vendor No.", VendorRequest."Purchase Order No.");
  end;

  /// <summary>
  /// Prepares an unsent request email and returns the vendor collaboration email scenario without issuing a token.
  /// </summary>
  /// <param name="RequestNo">The persisted request to load.</param>
  /// <param name="AccessLink">The HTTPS bearer link to include; must not be logged.</param>
  /// <param name="EmailMessage">Receives the prepared message with configured reply-to and optional order PDF.</param>
  /// <param name="EmailScenario">Receives the vendor collaboration scenario.</param>
  [NonDebuggable]
  procedure Prepare(RequestNo: Code[20]; AccessLink: Text; var EmailMessage: Codeunit "Email Message"; var EmailScenario: Enum "Email Scenario")
  begin
    this.Prepare(RequestNo, AccessLink, EmailMessage);
    EmailScenario := Enum::"Email Scenario"::"AMC Vendor Collaboration";
  end;

  /// <summary>
  /// Loads the request and prepares an unsent email without issuing a token.
  /// </summary>
  /// <param name="RequestNo">The persisted request to load.</param>
  /// <param name="AccessLink">The HTTPS bearer link to include; must not be logged.</param>
  /// <param name="EmailMessage">Receives the prepared message with configured reply-to and optional order PDF.</param>
  [NonDebuggable]
  procedure Prepare(RequestNo: Code[20]; AccessLink: Text; var EmailMessage: Codeunit "Email Message")
  var
    VendorRequest: Record "AMC Vendor Request";
  begin
    if not VendorRequest.Get(RequestNo) then
      Error(this.RequiredRecordNotFoundErr, VendorRequest.TableCaption());
    this.Prepare(VendorRequest, AccessLink, EmailMessage);
  end;

  /// <summary>
  /// Resolves the recipient and builds an unsent localized HTML email with buyer reply-to and an optional order PDF.
  /// </summary>
  /// <param name="VendorRequest">The request snapshot supplying content and recipient context.</param>
  /// <param name="AccessLink">The HTTPS bearer link to include; must not be logged.</param>
  /// <param name="EmailMessage">Receives the prepared email; no token is issued and no email is sent.</param>
  [NonDebuggable]
  procedure Prepare(VendorRequest: Record "AMC Vendor Request"; AccessLink: Text; var EmailMessage: Codeunit "Email Message")
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    VendorEmailBuilder: Codeunit "AMC Vendor Email Builder";
    HtmlBody: Text;
    PlainTextBody: Text;
    Recipient: Text;
    ReplyTo: Text;
    Subject: Text;
  begin
    Recipient := this.GetRecipient(VendorRequest);
    VendorEmailBuilder.Build(VendorRequest, AccessLink, Subject, HtmlBody, PlainTextBody);
    EmailMessage.Create(Recipient, Subject, HtmlBody, true, false);
    ReplyTo := this.GetBuyerEmail(VendorRequest);
    if ReplyTo <> '' then begin
      EmailMessage.SetHeader('Reply-To', ReplyTo);
      EmailMessage.FlushHeaders();
    end;

    CollaborationSetup.GetSetup();
    if CollaborationSetup."Attach Order PDF" then
      this.AddPurchaseOrderPdf(VendorRequest, EmailMessage);
  end;

  local procedure GetRecipient(VendorRequest: Record "AMC Vendor Request"): Text
  var
    Vendor: Record Vendor;
    VendorCard: Page "Vendor Card";
    MissingRecipientError: ErrorInfo;
    OpenVendorCardLbl: Label 'Open %1', Comment = '%1 = page caption';
  begin
    Vendor.SetLoadFields("AMC Portal Contact E-Mail", "E-Mail");
    if not Vendor.Get(VendorRequest."Vendor No.") then
      Error(this.RequiredRecordNotFoundErr, Vendor.TableCaption());
    if Vendor."AMC Portal Contact E-Mail" <> '' then
      exit(Vendor."AMC Portal Contact E-Mail");
    if Vendor."E-Mail" <> '' then
      exit(Vendor."E-Mail");

    MissingRecipientError.Message(StrSubstNo(this.VCHReq0003Err, Vendor."No."));
    MissingRecipientError.PageNo(Page::"Vendor Card");
    MissingRecipientError.RecordId(Vendor.RecordId());
    MissingRecipientError.AddNavigationAction(StrSubstNo(OpenVendorCardLbl, VendorCard.Caption()));
    Error(MissingRecipientError);
  end;

  local procedure GetBuyerEmail(VendorRequest: Record "AMC Vendor Request"): Text
  var
    SalespersonPurchaser: Record "Salesperson/Purchaser";
  begin
    SalespersonPurchaser.SetLoadFields("E-Mail");
    if (VendorRequest."Purchaser Code" <> '') and SalespersonPurchaser.Get(VendorRequest."Purchaser Code") then
      exit(SalespersonPurchaser."E-Mail");
    exit('');
  end;

  [NonDebuggable]
  local procedure CreateAccessLink(VendorRequest: Record "AMC Vendor Request"; RawToken: Text): Text
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    AccessLinkPatternLbl: Label '%1/request/%2?token=%3', Locked = true, Comment = '%1 = portal base URL, %2 = request number, %3 = secret token';
  begin
    CollaborationSetup.GetSetup();
    exit(StrSubstNo(AccessLinkPatternLbl, CollaborationSetup."Portal Base URL", VendorRequest."No.", RawToken));
  end;

  local procedure StampTokenSent(TokenHash: Text[64]; Recipient: Text)
  var
    VendorAccessToken: Record "AMC Vendor Access Token";
  begin
    VendorAccessToken.SetRange("Token Hash", TokenHash);
    if not VendorAccessToken.FindFirst() then
      Error(this.RequiredRecordNotFoundErr, VendorAccessToken.TableCaption());
    VendorAccessToken.Validate("Sent To E-Mail", CopyStr(Recipient, 1, MaxStrLen(VendorAccessToken."Sent To E-Mail")));
    VendorAccessToken.Validate("Sent At", CurrentDateTime());
    VendorAccessToken.Modify(true);
  end;

  [NonDebuggable]
  local procedure AddPurchaseOrderPdf(VendorRequest: Record "AMC Vendor Request"; var EmailMessage: Codeunit "Email Message")
  var
    PurchaseHeader: Record "Purchase Header";
    ReportSelections: Record "Report Selections";
    TempReportSelections: Record "Report Selections" temporary;
    DesignTimeReportSelection: Codeunit "Design-time Report Selection";
    TempBlob: Codeunit "Temp Blob";
    AttachmentInStream: InStream;
    LastErrorText: Text;
    PdfGenerationFailedErr: Label 'The purchase order PDF could not be generated: %1', Comment = '%1 = original error detail';
    PurchaseOrderPdfFileNameLbl: Label 'Purchase Order %1.pdf', Comment = '%1 = purchase order number';
  begin
    if not ReportSelections.FindEmailAttachmentUsageForVend("Report Selection Usage"::"P.Order", VendorRequest."Vendor No.", TempReportSelections) then
      exit;
    TempReportSelections.SetFilter("Report ID", '<>0');
    if not TempReportSelections.FindSet() then
      exit;

    if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorRequest."Purchase Order No.") then
      Error(this.RequiredRecordNotFoundErr, PurchaseHeader.TableCaption());
    PurchaseHeader.SetRecFilter();
    repeat
      Clear(TempBlob);
      if not this.TrySavePurchaseOrderPdf(TempReportSelections, PurchaseHeader, TempBlob) then begin
        LastErrorText := GetLastErrorText();
        DesignTimeReportSelection.ClearLayoutSelection();
        Error(PdfGenerationFailedErr, LastErrorText);
      end;
      DesignTimeReportSelection.ClearLayoutSelection();
      TempBlob.CreateInStream(AttachmentInStream);
      EmailMessage.AddAttachment(StrSubstNo(PurchaseOrderPdfFileNameLbl, PurchaseHeader."No."), 'application/pdf', AttachmentInStream);
    until TempReportSelections.Next() = 0;
  end;

  [TryFunction]
  [CommitBehavior(CommitBehavior::Ignore)]
  local procedure TrySavePurchaseOrderPdf(var TempReportSelections: Record "Report Selections" temporary; PurchaseHeader: Record "Purchase Header"; var TempBlob: Codeunit "Temp Blob")
  begin
    // The standard helper clears its layout on success, but explicitly commits.
    // Suppress only that rendering scope so issuing/superseding tokens stays atomic.
    TempReportSelections.SaveReportAsPDFInTempBlob(TempBlob, TempReportSelections."Report ID", PurchaseHeader, TempReportSelections."Custom Report Layout Code", "Report Selection Usage"::"P.Order");
  end;

  [TryFunction]
  [NonDebuggable]
  local procedure TrySend(Email: Codeunit Email; EmailMessage: Codeunit "Email Message")
  begin
    if not Email.Send(EmailMessage, Enum::"Email Scenario"::"AMC Vendor Collaboration") then
      Error(this.EmailNotSentErr);
  end;

  // Existing bypass retained with metadata only; see Docs/email-send-transaction-and-test-seam.md.
  /// <summary>
  /// Publishes notification metadata before email handoff through the retained legacy test seam.
  /// </summary>
  /// <param name="RequestNo">The request being notified; no bearer link or message content is exposed.</param>
  /// <param name="EmailScenario">The email scenario selected for delivery.</param>
  /// <param name="IsHandled">Set to true only when the subscriber replaces the standard email handoff.</param>
  /// <param name="EmailWasSent">The replacement handoff result, used when IsHandled is true.</param>
  [IntegrationEvent(false, false)]
  local procedure OnSendOnBeforeEmailSend(RequestNo: Code[20]; EmailScenario: Enum "Email Scenario"; var IsHandled: Boolean; var EmailWasSent: Boolean)
  begin
  end;

  var
    RequiredRecordNotFoundErr: Label 'The %1 record required to send the vendor notification could not be found.', Comment = '%1 = table caption';
    VCHReq0003Err: Label 'VCH-REQ-0003: Vendor %1 does not have a portal contact email address or email address.', Comment = '%1 = vendor number';
    EmailNotSentErr: Label 'The vendor access link email was not sent.';
    LinkSentDescriptionLbl: Label 'Vendor access link email sent.';
}
