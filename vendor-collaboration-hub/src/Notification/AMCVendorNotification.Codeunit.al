namespace Addmecode.VendorCollaborationHub;

using Microsoft.CRM.Team;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Email;
using System.Utilities;

codeunit 50118 "AMC Vendor Notification"
{
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
  begin
    VendorRequest.Get(RequestNo);
    this.AssertRecipientExists(VendorRequest);

    AccessLink := this.CreateAccessLink(VendorRequest, AccessTokenMgt.Issue(RequestNo));
    this.Prepare(VendorRequest, AccessLink, EmailMessage);
    if not this.TrySend(Email, EmailMessage) then begin
      LastErrorText := GetLastErrorText();
      if LastErrorText = '' then
        LastErrorText := this.EmailNotSentErr;
      CollabLog.LogEvent("AMC Source Type"::Request, VendorRequest."No.", 0, "AMC Collab Entry Type"::LinkSendFailed, "AMC Actor Type"::Buyer, '', UserId(), false, CopyStr(LastErrorText, 1, 250), CreateGuid());
      Telemetry.LogLinkSendFailed(VendorRequest."No.", VendorRequest."Vendor No.", VendorRequest."Purchase Order No.");
      Error(LastErrorText);
    end;

    CollabLog.LogEvent("AMC Source Type"::Request, VendorRequest."No.", 0, "AMC Collab Entry Type"::LinkSent, "AMC Actor Type"::Buyer, '', UserId(), false, this.LinkSentDescriptionLbl, CreateGuid());
    Telemetry.LogLinkSent(VendorRequest."No.", VendorRequest."Vendor No.", VendorRequest."Purchase Order No.");
  end;

  procedure Prepare(RequestNo: Code[20]; AccessLink: Text; var EmailMessage: Codeunit "Email Message"; var EmailScenario: Enum "Email Scenario")
  begin
    this.Prepare(RequestNo, AccessLink, EmailMessage);
    EmailScenario := Enum::"Email Scenario"::"Vendor Collaboration";
  end;

  procedure Prepare(RequestNo: Code[20]; AccessLink: Text; var EmailMessage: Codeunit "Email Message")
  var
    VendorRequest: Record "AMC Vendor Request";
  begin
    VendorRequest.Get(RequestNo);
    this.Prepare(VendorRequest, AccessLink, EmailMessage);
  end;

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
    EmailMessage.Create(Recipient, Subject, HtmlBody, true, true);
    ReplyTo := this.GetBuyerEmail(VendorRequest);
    if ReplyTo <> '' then begin
      EmailMessage.SetHeader('Reply-To', ReplyTo);
      EmailMessage.FlushHeaders();
    end;

    CollaborationSetup.GetSetup();
    if CollaborationSetup."Attach Order PDF" then
      this.AddPurchaseOrderPdf(VendorRequest, EmailMessage);
  end;

  local procedure AssertRecipientExists(VendorRequest: Record "AMC Vendor Request")
  begin
    this.GetRecipient(VendorRequest);
  end;

  local procedure GetRecipient(VendorRequest: Record "AMC Vendor Request"): Text
  var
    Vendor: Record Vendor;
  begin
    Vendor.Get(VendorRequest."Vendor No.");
    if Vendor."AMC Portal Contact E-Mail" <> '' then
      exit(Vendor."AMC Portal Contact E-Mail");
    if Vendor."E-Mail" <> '' then
      exit(Vendor."E-Mail");

    Error(this.VCHReq0003Err, Vendor."No.");
  end;

  local procedure GetBuyerEmail(VendorRequest: Record "AMC Vendor Request"): Text
  var
    SalespersonPurchaser: Record "Salesperson/Purchaser";
  begin
    if (VendorRequest."Purchaser Code" <> '') and SalespersonPurchaser.Get(VendorRequest."Purchaser Code") then
      exit(SalespersonPurchaser."E-Mail");
  end;

  local procedure CreateAccessLink(VendorRequest: Record "AMC Vendor Request"; RawToken: Text): Text
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
  begin
    CollaborationSetup.GetSetup();
    exit(CollaborationSetup."Portal Base URL" + '/request/' + VendorRequest."No." + '?token=' + RawToken);
  end;

  local procedure AddPurchaseOrderPdf(VendorRequest: Record "AMC Vendor Request"; var EmailMessage: Codeunit "Email Message")
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseHeaderRef: RecordRef;
    TempBlob: Codeunit "Temp Blob";
    AttachmentInStream: InStream;
    AttachmentOutStream: OutStream;
    PdfGenerationFailedErr: Label 'The purchase order PDF could not be generated.';
    PurchaseOrderPdfFileNameLbl: Label 'Purchase Order %1.pdf', Comment = '%1 = purchase order number';
  begin
    PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorRequest."Purchase Order No.");
    PurchaseHeader.SetRecFilter();
    PurchaseHeaderRef.GetTable(PurchaseHeader);
    TempBlob.CreateOutStream(AttachmentOutStream);
    if not Report.SaveAs(Report::Order, '', ReportFormat::Pdf, AttachmentOutStream, PurchaseHeaderRef) then
      Error(PdfGenerationFailedErr);
    TempBlob.CreateInStream(AttachmentInStream);
    EmailMessage.AddAttachment(StrSubstNo(PurchaseOrderPdfFileNameLbl, PurchaseHeader."No."), 'application/pdf', AttachmentInStream);
  end;

  [TryFunction]
  local procedure TrySend(Email: Codeunit Email; EmailMessage: Codeunit "Email Message")
  begin
    if not Email.Send(EmailMessage, Enum::"Email Scenario"::"Vendor Collaboration") then
      Error(this.EmailNotSentErr);
  end;

  var
    VCHReq0003Err: Label 'VCH-REQ-0003: Vendor %1 does not have a portal contact email address or email address.', Comment = '%1 = vendor number';
    EmailNotSentErr: Label 'The vendor access link email was not sent.';
    LinkSentDescriptionLbl: Label 'Vendor access link email sent.';
}
