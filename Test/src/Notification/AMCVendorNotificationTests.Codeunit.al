namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.CRM.Team;
using Microsoft.Foundation.NoSeries;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Email;
using System.Globalization;
using System.TestLibraries.Utilities;

codeunit 50144 "AMC Vendor Notification Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";

  [Test]
  procedure GivenVendorRequest_WhenBuildingEmail_ThenSubjectAndSafeBodiesContainTheAccessLink()
  var
    VendorRequest: Record "AMC Vendor Request";
    VendorEmailBuilder: Codeunit "AMC Vendor Email Builder";
    AccessLink: Text;
    HtmlBody: Text;
    OriginalLanguageId: Integer;
    PlainTextBody: Text;
    RequestNo: Code[20];
    Subject: Text;
  begin
    // Given
    RequestNo := this.CreateVendorRequest('portal@contoso.com', 'vendor@contoso.com', 'buyer@contoso.com', '');
    VendorRequest.Get(RequestNo);
    AccessLink := 'https://portal.contoso.com/request/' + RequestNo + '?token=abc&source=email';
    OriginalLanguageId := GlobalLanguage();

    // When
    VendorEmailBuilder.Build(VendorRequest, AccessLink, Subject, HtmlBody, PlainTextBody);

    // Then
    this.Assert.IsTrue(StrPos(Subject, VendorRequest."Purchase Order No.") > 0, 'The subject must contain the purchase order number.');
    this.Assert.IsTrue(StrPos(HtmlBody, '<table>') > 0, 'The HTML body must contain a summary table.');
    this.Assert.IsTrue(StrPos(HtmlBody, '<a href="https://portal.contoso.com/request/') > 0, 'The HTML body must contain the access link button.');
    this.Assert.IsTrue(StrPos(HtmlBody, '&lt;item&gt; &amp; &quot;quoted&quot;') > 0, 'Snapshot descriptions must be HTML encoded.');
    this.Assert.IsFalse(StrPos(HtmlBody, '<form') > 0, 'The HTML body must not contain forms.');
    this.Assert.IsFalse(StrPos(HtmlBody, '<script') > 0, 'The HTML body must not contain scripts.');
    this.Assert.IsFalse(StrPos(HtmlBody, '<font') > 0, 'The HTML body must not contain fonts.');
    this.Assert.IsFalse(StrPos(HtmlBody, '<img') > 0, 'The HTML body must not contain tracking images.');
    this.Assert.IsTrue(StrPos(PlainTextBody, AccessLink) > 0, 'The plain-text body must contain the same access link.');
    this.Assert.IsTrue(StrPos(PlainTextBody, 'Lines: 2') > 0, 'The plain-text body must contain the line count.');
    this.Assert.IsTrue(StrPos(PlainTextBody, 'First <item> & "quoted"; Second item') > 0, 'The plain-text body must contain the first-line excerpt.');
    this.Assert.AreEqual(OriginalLanguageId, GlobalLanguage(), 'The email builder must restore GlobalLanguage after a successful build.');
  end;

  [Test]
  procedure GivenVendorRequest_WhenPreparingNotification_ThenCollaborationScenarioAndBuyerReplyToAreUsed()
  var
    Body: Text;
    EmailMessage: Codeunit "Email Message";
    VendorNotification: Codeunit "AMC Vendor Notification";
    EmailScenario: Enum "Email Scenario";
    ReplyTo: Text;
    RequestNo: Code[20];
  begin
    // Given
    RequestNo := this.CreateVendorRequest('portal@contoso.com', 'vendor@contoso.com', 'buyer@contoso.com', '');

    // When
    VendorNotification.Prepare(RequestNo, 'https://portal.contoso.com/access', EmailMessage, EmailScenario);

    // Then
    this.Assert.AreEqual(Enum::"Email Scenario"::"Vendor Collaboration", EmailScenario, 'The collaboration email scenario must be used.');
    Body := EmailMessage.GetBody();
    this.Assert.IsTrue(StrPos(Body, '<a href="https://portal.contoso.com/access">Open vendor request</a>') > 0, 'The prepared notification must retain the access link.');
    this.Assert.IsTrue(EmailMessage.GetHeader('Reply-To', ReplyTo), 'The prepared notification must include a Reply-To header.');
    this.Assert.AreEqual('buyer@contoso.com', ReplyTo, 'The Reply-To header must use the buyer email address.');
  end;

  [Test]
  procedure GivenVendorWithPortalContactEmail_WhenPreparingNotification_ThenPortalContactIsTheRecipient()
  var
    EmailMessage: Codeunit "Email Message";
    VendorNotification: Codeunit "AMC Vendor Notification";
    Recipients: List of [Text];
    RequestNo: Code[20];
  begin
    // Given
    RequestNo := this.CreateVendorRequest('portal@contoso.com', 'vendor@contoso.com', 'buyer@contoso.com', '');

    // When
    VendorNotification.Prepare(RequestNo, 'https://portal.contoso.com/access', EmailMessage);
    EmailMessage.GetRecipients(Enum::"Email Recipient Type"::"To", Recipients);

    // Then
    this.Assert.AreEqual(1, Recipients.Count(), 'A vendor notification must have one recipient.');
    this.Assert.AreEqual('portal@contoso.com', Recipients.Get(1), 'The portal contact email must take precedence over the vendor email.');
  end;

  [Test]
  procedure GivenVendorWithoutPortalContactEmail_WhenPreparingNotification_ThenVendorEmailIsTheRecipient()
  var
    EmailMessage: Codeunit "Email Message";
    VendorNotification: Codeunit "AMC Vendor Notification";
    Recipients: List of [Text];
    RequestNo: Code[20];
  begin
    // Given
    RequestNo := this.CreateVendorRequest('', 'vendor@contoso.com', 'buyer@contoso.com', '');

    // When
    VendorNotification.Prepare(RequestNo, 'https://portal.contoso.com/access', EmailMessage);
    EmailMessage.GetRecipients(Enum::"Email Recipient Type"::"To", Recipients);

    // Then
    this.Assert.AreEqual(1, Recipients.Count(), 'A vendor notification must have one recipient.');
    this.Assert.AreEqual('vendor@contoso.com', Recipients.Get(1), 'The vendor email must be used when the portal contact email is blank.');
  end;

  [Test]
  procedure GivenVendorWithoutEmailAddresses_WhenSendingNotification_ThenNoTokenIsIssued()
  var
    VendorAccessToken: Record "AMC Vendor Access Token";
    VendorNotification: Codeunit "AMC Vendor Notification";
    RequestNo: Code[20];
    VCHReq0003Err: Label 'VCH-REQ-0003: Vendor %1 does not have a portal contact email address or email address.', Comment = '%1 = vendor number';
    VendorRequest: Record "AMC Vendor Request";
  begin
    // Given
    RequestNo := this.CreateVendorRequest('', '', 'buyer@contoso.com', '');
    VendorRequest.Get(RequestNo);
    Commit();

    // When
    asserterror VendorNotification.Send(RequestNo);

    // Then
    this.Assert.ExpectedError(StrSubstNo(VCHReq0003Err, VendorRequest."Vendor No."));
    VendorAccessToken.SetRange("Request No.", RequestNo);
    this.Assert.IsTrue(VendorAccessToken.IsEmpty(), 'A token must not be issued when no recipient email address is available.');
  end;

  [Test]
  procedure GivenVendorWithoutEmailAddresses_WhenPreparingNotification_ThenVCHReq0003IsRaised()
  var
    EmailMessage: Codeunit "Email Message";
    VendorNotification: Codeunit "AMC Vendor Notification";
    RequestNo: Code[20];
    VCHReq0003Err: Label 'VCH-REQ-0003: Vendor %1 does not have a portal contact email address or email address.', Comment = '%1 = vendor number';
    VendorRequest: Record "AMC Vendor Request";
  begin
    // Given
    RequestNo := this.CreateVendorRequest('', '', 'buyer@contoso.com', '');
    VendorRequest.Get(RequestNo);
    Commit();

    // When
    asserterror VendorNotification.Prepare(RequestNo, 'https://portal.contoso.com/access', EmailMessage);

    // Then
    this.Assert.ExpectedError(StrSubstNo(VCHReq0003Err, VendorRequest."Vendor No."));
  end;

  [Test]
  procedure GivenBuilderError_WhenBuildingEmail_ThenGlobalLanguageIsRestored()
  var
    Language: Codeunit Language;
    TempVendorRequest: Record "AMC Vendor Request" temporary;
    VendorEmailBuilder: Codeunit "AMC Vendor Email Builder";
    HtmlBody: Text;
    OriginalLanguageId: Integer;
    PlainTextBody: Text;
    Subject: Text;
    InvalidAccessLinkErr: Label 'The vendor access link must be an absolute HTTPS URL.';
  begin
    // Given
    TempVendorRequest.Init();
    TempVendorRequest."No." := this.CreateUniqueCode();
    TempVendorRequest."Language Code" := Language.GetLanguageCode(Language.GetDefaultApplicationLanguageId());
    OriginalLanguageId := GlobalLanguage();
    Commit();

    // When
    asserterror VendorEmailBuilder.Build(TempVendorRequest, 'javascript:alert(1)', Subject, HtmlBody, PlainTextBody);

    // Then
    this.Assert.ExpectedError(InvalidAccessLinkErr);
    this.Assert.AreEqual(OriginalLanguageId, GlobalLanguage(), 'The email builder must restore GlobalLanguage after an error.');
  end;

  local procedure CreateVendorRequest(PortalContactEmail: Text[80]; VendorEmail: Text[80]; BuyerEmail: Text[80]; VendorLanguageCode: Code[10]): Code[20]
  var
    PurchaseHeader: Record "Purchase Header";
    RequestMgt: Codeunit "AMC Request Mgt";
    Vendor: Record Vendor;
    BuyerCode: Code[20];
    VendorNo: Code[20];
  begin
    this.ConfigureEnabledSetup();
    VendorNo := this.CreateUniqueCode();
    BuyerCode := this.CreateUniqueCode();
    this.CreateVendor(Vendor, VendorNo, PortalContactEmail, VendorEmail, VendorLanguageCode);
    this.CreateBuyer(BuyerCode, BuyerEmail);
    this.CreatePurchaseOrder(PurchaseHeader, VendorNo, BuyerCode);
    this.CreatePurchaseLine(PurchaseHeader, 10000, 'First <item> & "quoted"');
    this.CreatePurchaseLine(PurchaseHeader, 20000, 'Second item');
    exit(RequestMgt.CreateFromOrder(PurchaseHeader));
  end;

  local procedure ConfigureEnabledSetup()
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    ProposalNoSeriesCode: Code[20];
    RequestNoSeriesCode: Code[20];
  begin
    RequestNoSeriesCode := this.CreateUniqueCode();
    ProposalNoSeriesCode := this.CreateUniqueCode();
    this.CreateNoSeries(RequestNoSeriesCode);
    this.CreateNoSeries(ProposalNoSeriesCode);

    CollaborationSetup.GetSetup();
    CollaborationSetup.Enabled := false;
    CollaborationSetup.Modify(true);
    CollaborationSetup."Request Nos." := RequestNoSeriesCode;
    CollaborationSetup."Proposal Nos." := ProposalNoSeriesCode;
    CollaborationSetup."Portal Base URL" := 'https://portal.contoso.com';
    CollaborationSetup."Portal Support E-Mail" := 'support@contoso.com';
    CollaborationSetup."Attach Order PDF" := false;
    CollaborationSetup.Validate(Enabled, true);
    CollaborationSetup.Modify(true);
  end;

  local procedure CreateNoSeries(NoSeriesCode: Code[20])
  var
    NoSeries: Record "No. Series";
    NoSeriesLine: Record "No. Series Line";
    StartingNo: Code[20];
  begin
    StartingNo := CopyStr('R' + DelChr(Format(CreateGuid()), '=', '{}-') + '1', 1, 20);
    NoSeries.Init();
    NoSeries.Code := NoSeriesCode;
    NoSeries.Description := NoSeriesCode;
    NoSeries."Default Nos." := true;
    NoSeries.Insert(false);

    NoSeriesLine.Init();
    NoSeriesLine."Series Code" := NoSeriesCode;
    NoSeriesLine."Line No." := 10000;
    NoSeriesLine."Starting No." := StartingNo;
    NoSeriesLine."Increment-by No." := 1;
    NoSeriesLine.Open := true;
    NoSeriesLine.Insert(false);
  end;

  local procedure CreateVendor(var Vendor: Record Vendor; VendorNo: Code[20]; PortalContactEmail: Text[80]; VendorEmail: Text[80]; VendorLanguageCode: Code[10])
  begin
    Vendor.Init();
    Vendor."No." := VendorNo;
    Vendor.Name := VendorNo;
    Vendor."E-Mail" := VendorEmail;
    Vendor."Language Code" := VendorLanguageCode;
    Vendor."AMC Collaboration Enabled" := true;
    Vendor."AMC Portal Contact E-Mail" := PortalContactEmail;
    Vendor.Insert(false);
  end;

  local procedure CreateBuyer(BuyerCode: Code[20]; BuyerEmail: Text[80])
  var
    SalespersonPurchaser: Record "Salesperson/Purchaser";
  begin
    SalespersonPurchaser.Init();
    SalespersonPurchaser.Code := BuyerCode;
    SalespersonPurchaser.Name := BuyerCode;
    SalespersonPurchaser."E-Mail" := BuyerEmail;
    SalespersonPurchaser.Insert(false);
  end;

  local procedure CreatePurchaseOrder(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; BuyerCode: Code[20])
  begin
    PurchaseHeader.Init();
    PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
    PurchaseHeader."No." := this.CreateUniqueCode();
    PurchaseHeader."Buy-from Vendor No." := VendorNo;
    PurchaseHeader."Purchaser Code" := BuyerCode;
    PurchaseHeader.Status := PurchaseHeader.Status::Open;
    PurchaseHeader.Insert(false);
  end;

  local procedure CreatePurchaseLine(PurchaseHeader: Record "Purchase Header"; LineNo: Integer; Description: Text[100])
  var
    PurchaseLine: Record "Purchase Line";
  begin
    PurchaseLine.Init();
    PurchaseLine."Document Type" := PurchaseHeader."Document Type";
    PurchaseLine."Document No." := PurchaseHeader."No.";
    PurchaseLine."Line No." := LineNo;
    PurchaseLine."No." := this.CreateUniqueCode();
    PurchaseLine.Description := Description;
    PurchaseLine.Quantity := 1;
    PurchaseLine.Insert(false);
  end;

  local procedure CreateUniqueCode(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
