namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Foundation.NoSeries;
using Microsoft.Finance.Currency;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Globalization;
using System.TestLibraries.Utilities;

codeunit 50131 "AMC Request Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        OpenCreatedVendorRequest: Boolean;
        VendorRequestPageWasOpened: Boolean;
        ExpectedPurchaseOrderNo: Code[20];

    [Test]
    procedure GivenEnabledVendorAndOpenOrder_WhenCreateFromOrder_ThenDraftRequestAndSnapshotAreCreated()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        PurchaseHeader: Record "Purchase Header";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        this.CreatePurchaseLine(PurchaseHeader, 10000, 'ITEM-ONE', 'RED', 'First item', 'MAIN', 'PCS', 10, 20260915D);
        this.CreatePurchaseLine(PurchaseHeader, 20000, 'ITEM-TWO', '', 'Second item', 'EAST', 'BOX', 5, 20260920D);

        // When
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::Draft, VendorRequest.Status, 'The request must be created as Draft.');
        this.Assert.AreEqual(VendorNo, VendorRequest."Vendor No.", 'The request must refer to the purchase order vendor.');
        this.Assert.AreEqual(PurchaseHeader."No.", VendorRequest."Purchase Order No.", 'The request must refer to its source purchase order.');
        this.Assert.AreEqual(PurchaseHeader."Assigned User ID", VendorRequest."Assigned User ID", 'The request must retain the assigned user from the purchase order.');
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No.");
        this.Assert.AreEqual(RequestNo, PurchaseHeader."AMC Active Request No.", 'The purchase order must point to the active request.');
        this.Assert.AreEqual(PurchaseHeader."AMC Collaboration Status"::Draft, PurchaseHeader."AMC Collaboration Status", 'The purchase order collaboration status must be Draft.');
        this.AssertRequestLine(RequestNo, 10000, 'ITEM-ONE', 'RED', 'First item', 'MAIN', 'PCS', 10, 20260915D);
        this.AssertRequestLine(RequestNo, 20000, 'ITEM-TWO', '', 'Second item', 'EAST', 'BOX', 5, 20260920D);
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", RequestNo);
        CollaborationEntry.SetRange("Entry Type", "AMC Collab Entry Type"::RequestCreated);
        this.Assert.IsFalse(CollaborationEntry.IsEmpty(), 'Creating a request must log a RequestCreated event.');
    end;

    [Test]
    [HandlerFunctions('ConfirmCreatedVendorRequestHandler,VendorRequestPageHandler')]
    procedure GivenOpenPurchaseOrder_WhenSendToVendorCollaborationAndBuyerChoosesYes_ThenCreatedRequestPageOpensForSourceOrder()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorRequest: Record "AMC Vendor Request";
        PurchaseOrder: TestPage "Purchase Order";
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        this.OpenCreatedVendorRequest := true;
        this.VendorRequestPageWasOpened := false;
        this.ExpectedPurchaseOrderNo := PurchaseHeader."No.";
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchaseHeader);

        // When
        PurchaseOrder.AMCCreateVendorRequest.Invoke();

        // Then
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No.");
        VendorRequest.Get(PurchaseHeader."AMC Active Request No.");
        this.Assert.AreEqual(PurchaseHeader."No.", VendorRequest."Purchase Order No.", 'The created request must refer to the source purchase order.');
        this.Assert.IsTrue(this.VendorRequestPageWasOpened, 'The created vendor request page must open when the buyer chooses Yes.');
    end;

    [Test]
    [HandlerFunctions('ConfirmCreatedVendorRequestHandler')]
    procedure GivenOpenPurchaseOrder_WhenSendToVendorCollaborationAndBuyerChoosesNo_ThenRequestIsCreatedWithoutOpeningRequestPage()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorRequest: Record "AMC Vendor Request";
        PurchaseOrder: TestPage "Purchase Order";
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        this.OpenCreatedVendorRequest := false;
        this.VendorRequestPageWasOpened := false;
        PurchaseOrder.OpenEdit();
        PurchaseOrder.GotoRecord(PurchaseHeader);

        // When
        PurchaseOrder.AMCCreateVendorRequest.Invoke();

        // Then
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No.");
        VendorRequest.Get(PurchaseHeader."AMC Active Request No.");
        this.Assert.AreEqual(PurchaseHeader."No.", VendorRequest."Purchase Order No.", 'The created request must refer to the source purchase order.');
        this.Assert.AreEqual(PurchaseHeader."AMC Collaboration Status"::Draft, PurchaseHeader."AMC Collaboration Status", 'The purchase order collaboration status must be Draft.');
        this.Assert.IsFalse(this.VendorRequestPageWasOpened, 'The created vendor request page must not open when the buyer chooses No.');
        PurchaseOrder.Close();
    end;

    [Test]
    procedure GivenActiveRequest_WhenCreateFromOrderAgain_ThenExistingRequestIsNamed()
    var
        PurchaseHeader: Record "Purchase Header";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        ActiveRequestErr: Label 'Purchase order %1 already has active vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);

        // When
        asserterror RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(ActiveRequestErr, PurchaseHeader."No.", RequestNo));
    end;

    [Test]
    procedure GivenReleasedPurchaseOrder_WhenCreateFromOrder_ThenUserIsDirectedToReopen()
    var
        PurchaseHeader: Record "Purchase Header";
        RequestMgt: Codeunit "AMC Request Mgt";
        VendorNo: Code[20];
        ReleasedOrderErr: Label 'Purchase order %1 must be open. Use the Reopen action before creating a vendor request.', Comment = '%1 = purchase order number';
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Released);

        // When
        asserterror RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(ReleasedOrderErr, PurchaseHeader."No."));
    end;

    [Test]
    procedure GivenVendorWithoutCollaboration_WhenCreateFromOrder_ThenCreationIsRejected()
    var
        PurchaseHeader: Record "Purchase Header";
        RequestMgt: Codeunit "AMC Request Mgt";
        VendorNo: Code[20];
        VendorNotEnabledErr: Label 'Vendor %1 is not enabled for vendor collaboration.', Comment = '%1 = vendor number';
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(false);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);

        // When
        asserterror RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(VendorNotEnabledErr, VendorNo));
    end;

    [Test]
    procedure GivenDisabledCollaborationSetup_WhenCreateFromOrder_ThenCreationIsRejected()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        PurchaseHeader: Record "Purchase Header";
        RequestMgt: Codeunit "AMC Request Mgt";
        VendorNo: Code[20];
        CollaborationNotEnabledErr: Label 'Vendor collaboration is not enabled in Vendor Collaboration Setup.';
    begin
        // Given
        CollaborationSetup.GetSetup();
        CollaborationSetup.Enabled := false;
        CollaborationSetup.Modify(true);
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);

        // When
        asserterror RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        this.Assert.ExpectedError(CollaborationNotEnabledErr);
    end;

    [Test]
    procedure GivenCreatedRequest_WhenSourcePurchaseLineChanges_ThenSourceWriteIsBlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        VendorRequestLine: Record "AMC Vendor Request Line";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        PurchaseOrderLockedErr: Label 'Purchase order %1 is locked by active vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        this.CreatePurchaseLine(PurchaseHeader, 10000, 'ITEM-ONE', '', 'Original description', 'MAIN', 'PCS', 10, 20260915D);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000);
        PurchaseLine.Description := 'Changed description';
        Commit();

        // When
        asserterror PurchaseLine.Modify(true);

        // Then
        this.AssertExpectedError(StrSubstNo(PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));
        VendorRequestLine.Get(RequestNo, 10000);
        this.Assert.AreEqual('Original description', VendorRequestLine.Description, 'The request line must retain the original purchase line description.');
    end;

    [Test]
    procedure GivenNewRequestAndLine_WhenInitialized_ThenDefaultStatusesAreUsed()
    var
        TempVendorRequest: Record "AMC Vendor Request" temporary;
        TempVendorRequestLine: Record "AMC Vendor Request Line" temporary;
    begin
        // Given
        TempVendorRequest.Init();
        TempVendorRequestLine.Init();

        // When

        // Then
        this.Assert.AreEqual(TempVendorRequest.Status::Draft, TempVendorRequest.Status, 'A new vendor request must start as Draft.');
        this.Assert.AreEqual(TempVendorRequestLine.Status::Open, TempVendorRequestLine.Status, 'A new vendor request line must start as Open.');
    end;

    [Test]
    procedure GivenVendorLanguageOrNoLanguage_WhenCreatingRequest_ThenVendorOrCompanyLanguageIsSnapshotted()
    var
        Language: Codeunit Language;
        PurchaseHeader: Record "Purchase Header";
        RequestMgt: Codeunit "AMC Request Mgt";
        VendorRequest: Record "AMC Vendor Request";
        CompanyLanguageCode: Code[10];
        RequestNo: Code[20];
        VendorLanguageCode: Code[10];
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        CompanyLanguageCode := Language.GetLanguageCode(Language.GetDefaultApplicationLanguageId());
        VendorLanguageCode := this.GetAlternateLanguageCode(CompanyLanguageCode);
        this.Assert.AreNotEqual('', VendorLanguageCode, 'The test requires an installed language distinct from the company language.');
        VendorNo := this.CreateVendorWithLanguage(true, VendorLanguageCode);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);

        // When
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorLanguageCode, VendorRequest."Language Code", 'The request must snapshot the vendor language code instead of the company language.');

        // Given
        VendorNo := this.CreateVendorWithLanguage(true, '');
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);

        // When
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);

        // Then
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(CompanyLanguageCode, VendorRequest."Language Code", 'The request must use the company language when the vendor language is blank.');
    end;

    [Test]
    procedure GivenVendorRequest_WhenPhysicalDeletionIsAttempted_ThenDeletionIsRejected()
    var
        VendorRequest: Record "AMC Vendor Request";
        RequestNo: Code[20];
        VendorRequestCannotBeDeletedErr: Label 'Vendor requests cannot be deleted. Cancel the request instead.';
    begin
        // Given
        RequestNo := this.CreateRequestNo();
        this.InsertVendorRequest(VendorRequest, RequestNo);

        // When
        asserterror VendorRequest.Delete(true);

        // Then
        this.Assert.ExpectedError(VendorRequestCannotBeDeletedErr);
    end;

  [Test]
  procedure GivenDraftRequest_WhenSetStatusThroughReviewWorkflow_ThenRequestIsClosed()
  var
    VendorRequest: Record "AMC Vendor Request";
    RequestMgt: Codeunit "AMC Request Mgt";
    RequestNo: Code[20];
  begin
    // Given
    RequestNo := this.CreateRequestNo();
    this.InsertVendorRequest(VendorRequest, RequestNo);

    // When
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::Sent);
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"Awaiting Vendor");
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"Vendor Responded");
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"In Review");
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::Closed);

    // Then
    VendorRequest.Get(RequestNo);
    this.Assert.AreEqual(VendorRequest.Status::Closed, VendorRequest.Status, 'The request must be closed after the review workflow.');
  end;

  [Test]
  procedure GivenAwaitingVendorRequest_WhenSetStatusToCancelled_ThenRequestIsCancelled()
  var
    VendorRequest: Record "AMC Vendor Request";
    RequestMgt: Codeunit "AMC Request Mgt";
    RequestNo: Code[20];
  begin
    // Given
    RequestNo := this.CreateRequestNo();
    this.InsertVendorRequest(VendorRequest, RequestNo);
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::Sent);
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"Awaiting Vendor");

    // When
    RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::Cancelled);

    // Then
    VendorRequest.Get(RequestNo);
    this.Assert.AreEqual(VendorRequest.Status::Cancelled, VendorRequest.Status, 'The awaiting vendor request must be cancelled.');
  end;

  [Test]
   procedure GivenDraftRequest_WhenSetStatusToInReview_ThenTransitionIsRejectedAndStatusIsUnchanged()
  var
    VendorRequest: Record "AMC Vendor Request";
    RequestMgt: Codeunit "AMC Request Mgt";
    RequestNo: Code[20];
    InvalidStatusTransitionErr: Label 'Vendor request status cannot change from %1 to %2.', Comment = '%1 = current request status, %2 = requested request status';
  begin
    // Given
    RequestNo := this.CreateRequestNo();
    this.InsertVendorRequest(VendorRequest, RequestNo);
    Commit();

    // When
    asserterror RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"In Review");

    // Then
    this.AssertExpectedError(StrSubstNo(InvalidStatusTransitionErr, VendorRequest.Status::Draft, VendorRequest.Status::"In Review"));
    VendorRequest.Get(RequestNo);
    this.Assert.AreEqual(VendorRequest.Status::Draft, VendorRequest.Status, 'An illegal transition must not change the request status.');
   end;

    [Test]
    procedure GivenDraftRequest_WhenSend_ThenRequestAwaitsVendorWithStampedActiveToken()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        PurchaseHeader: Record "Purchase Header";
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        VendorRequest.Get(RequestNo);
        // When
        this.SendRequestWithEmailHandOff(VendorRequest, true);

        // Then
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::"Awaiting Vendor", VendorRequest.Status, 'Sending must move the request to Awaiting Vendor.');
        this.Assert.AreNotEqual(0DT, VendorRequest."Sent Date Time", 'Sending must stamp the request sent time.');
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No.");
        this.Assert.AreEqual(PurchaseHeader."AMC Collaboration Status"::"Awaiting Vendor", PurchaseHeader."AMC Collaboration Status", 'Sending must update the purchase order collaboration status.');
        VendorAccessToken.SetRange("Request No.", RequestNo);
        this.Assert.AreEqual(1, VendorAccessToken.Count(), 'Sending must issue one access token.');
        VendorAccessToken.FindFirst();
        this.Assert.AreEqual(VendorAccessToken.Status::Active, VendorAccessToken.Status, 'The sent access token must be active.');
        this.Assert.AreEqual('vendor@contoso.com', VendorAccessToken."Sent To E-Mail", 'The sent access token must retain the recipient.');
        this.Assert.AreNotEqual(0DT, VendorAccessToken."Sent At", 'The sent access token must retain the send time.');
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", RequestNo);
        CollaborationEntry.SetRange("Entry Type", "AMC Collab Entry Type"::LinkSent);
        this.Assert.IsFalse(CollaborationEntry.IsEmpty(), 'Sending must add a LinkSent timeline entry.');
    end;

    [Test]
    procedure GivenDraftRequest_WhenEmailHandOffFails_ThenRequestAndTokenAreRolledBack()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        EmailSendHandler: Codeunit "AMC Email Send Test Handler";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        EmailNotSentErr: Label 'The vendor access link email was not sent.';
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        VendorRequest.Get(RequestNo);
        Commit();
        this.BindEmailSendHandler(EmailSendHandler, false);

        // When
        asserterror RequestMgt.Send(VendorRequest);
        this.UnbindEmailSendHandler(EmailSendHandler);

        // Then
        this.AssertExpectedError(EmailNotSentErr);
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::Draft, VendorRequest.Status, 'A failed email hand-off must retain Draft status.');
        VendorAccessToken.SetRange("Request No.", RequestNo);
        this.Assert.IsTrue(VendorAccessToken.IsEmpty(), 'A failed email hand-off must not retain an issued token.');
    end;

    [Test]
    procedure GivenSentRequestWithActiveToken_WhenRetryingSend_ThenOldTokenIsSupersededAndRequestAwaitsVendor()
    var
        OldVendorAccessToken: Record "AMC Vendor Access Token";
        PurchaseHeader: Record "Purchase Header";
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        VendorRequest.Get(RequestNo);
        RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::Sent);
        VendorAccessToken.SetRange("Token Hash", this.HashAndIssueToken(RequestNo));
        VendorAccessToken.FindFirst();
        OldVendorAccessToken.Get(VendorAccessToken."Token Id");

        // When
        VendorRequest.Get(RequestNo);
        this.SendRequestWithEmailHandOff(VendorRequest, true);

        // Then
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::"Awaiting Vendor", VendorRequest.Status, 'Retrying a sent request must move it to Awaiting Vendor.');
        OldVendorAccessToken.Get(OldVendorAccessToken."Token Id");
        this.Assert.AreEqual(OldVendorAccessToken.Status::Superseded, OldVendorAccessToken.Status, 'Retrying must supersede the prior active token.');
        VendorAccessToken.Reset();
        VendorAccessToken.SetRange("Request No.", RequestNo);
        VendorAccessToken.SetRange(Status, VendorAccessToken.Status::Active);
        this.Assert.AreEqual(1, VendorAccessToken.Count(), 'Retrying must issue one new active token.');
        VendorAccessToken.FindFirst();
        this.Assert.AreNotEqual(OldVendorAccessToken."Token Id", VendorAccessToken."Token Id", 'Retrying must issue a token different from the superseded token.');
    end;

    [Test]
    procedure GivenVendorWithoutEmail_WhenSend_ThenDraftRequestHasNoToken()
    var
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record Vendor;
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        VCHReq0003Err: Label 'VCH-REQ-0003: Vendor %1 does not have a portal contact email address or email address.', Comment = '%1 = vendor number';
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        Vendor.Get(VendorNo);
        Vendor."E-Mail" := '';
        Vendor.Modify(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        VendorRequest.Get(RequestNo);
        Commit();

        // When
        asserterror RequestMgt.Send(VendorRequest);

        // Then
        this.AssertExpectedError(StrSubstNo(VCHReq0003Err, VendorNo));
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::Draft, VendorRequest.Status, 'A request without a recipient must remain Draft.');
        VendorAccessToken.SetRange("Request No.", RequestNo);
        this.Assert.IsTrue(VendorAccessToken.IsEmpty(), 'A request without a recipient must not issue a token.');
    end;

    [Test]
    procedure GivenAwaitingVendorRequest_WhenResend_ThenOldTokenIsSupersededAndOtherRequestIsUnchanged()
    var
        OtherPurchaseHeader: Record "Purchase Header";
        OtherVendorAccessToken: Record "AMC Vendor Access Token";
        PurchaseHeader: Record "Purchase Header";
        OldVendorAccessToken: Record "AMC Vendor Access Token";
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        OtherRequestNo: Code[20];
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        VendorRequest.Get(RequestNo);
        this.SendRequestWithEmailHandOff(VendorRequest, true);
        VendorAccessToken.SetRange("Request No.", RequestNo);
        VendorAccessToken.FindFirst();
        OldVendorAccessToken.Get(VendorAccessToken."Token Id");

        this.CreatePurchaseOrder(OtherPurchaseHeader, VendorNo, OtherPurchaseHeader.Status::Open);
        OtherRequestNo := RequestMgt.CreateFromOrder(OtherPurchaseHeader);
        OtherVendorAccessToken.SetRange("Token Hash", this.HashAndIssueToken(OtherRequestNo));
        OtherVendorAccessToken.FindFirst();

        // When
        VendorRequest.Get(RequestNo);
        this.SendRequestWithEmailHandOff(VendorRequest, true);

        // Then
        OldVendorAccessToken.Get(OldVendorAccessToken."Token Id");
        this.Assert.AreEqual(OldVendorAccessToken.Status::Superseded, OldVendorAccessToken.Status, 'Re-sending must supersede the old request token.');
        VendorAccessToken.Reset();
        VendorAccessToken.SetRange("Request No.", RequestNo);
        VendorAccessToken.SetRange(Status, VendorAccessToken.Status::Active);
        this.Assert.AreEqual(1, VendorAccessToken.Count(), 'Re-sending must issue one new active token.');
        OtherVendorAccessToken.Get(OtherVendorAccessToken."Token Id");
        this.Assert.AreEqual(OtherVendorAccessToken.Status::Active, OtherVendorAccessToken.Status, 'Re-sending must not change tokens for other requests.');
    end;

    [Test]
    procedure GivenVendorResponseDaysExceedLinkValidity_WhenSend_ThenVCHReq0002LeavesDraftWithoutToken()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        PurchaseHeader: Record "Purchase Header";
        Vendor: Record Vendor;
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        VCHReq0002Err: Label 'VCH-REQ-0002: Link Validity Days (%1) must be greater than or equal to vendor response days (%2).', Comment = '%1 = link validity days, %2 = vendor response days';
    begin
        // Given
        this.ConfigureEnabledSetup();
        CollaborationSetup.GetSetup();
        CollaborationSetup."Link Validity Days" := 14;
        CollaborationSetup.Modify(true);
        VendorNo := this.CreateVendor(true);
        Vendor.Get(VendorNo);
        Vendor."AMC Response Days" := 15;
        Vendor.Modify(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        VendorRequest.Get(RequestNo);
        Commit();

        // When
        asserterror RequestMgt.Send(VendorRequest);

        // Then
        this.AssertExpectedError(StrSubstNo(VCHReq0002Err, 14, 15));
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::Draft, VendorRequest.Status, 'An invalid link lifetime must retain Draft status.');
        VendorAccessToken.SetRange("Request No.", RequestNo);
        this.Assert.IsTrue(VendorAccessToken.IsEmpty(), 'An invalid link lifetime must not issue a token.');
    end;

    local procedure CreateRequestNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure HashAndIssueToken(RequestNo: Code[20]): Text[64]
    var
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
    begin
        exit(AccessTokenMgt.HashToken(AccessTokenMgt.Issue(RequestNo)));
    end;

    local procedure AssertExpectedError(ExpectedError: Text)
    begin
        this.Assert.ExpectedError(ExpectedError);
        ClearLastError();
    end;

    [ConfirmHandler]
    procedure ConfirmCreatedVendorRequestHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        this.Assert.IsTrue(StrPos(Question, 'has been created') > 0, 'The confirmation must refer to a created request.');
        Reply := this.OpenCreatedVendorRequest;
    end;

    [PageHandler]
    procedure VendorRequestPageHandler(var VendorRequestPage: TestPage "AMC Vendor Request")
    begin
        VendorRequestPage."Purchase Order No.".AssertEquals(this.ExpectedPurchaseOrderNo);
        this.VendorRequestPageWasOpened := true;
    end;

    local procedure ConfigureEnabledSetup()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        RequestNoSeriesCode: Code[20];
        ProposalNoSeriesCode: Code[20];
    begin
        RequestNoSeriesCode := this.CreateNoSeriesCode();
        ProposalNoSeriesCode := this.CreateNoSeriesCode();
        this.CreateNoSeries(RequestNoSeriesCode);
        this.CreateNoSeries(ProposalNoSeriesCode);

        CollaborationSetup.GetSetup();
        CollaborationSetup.Enabled := false;
        CollaborationSetup.Modify(true);
        CollaborationSetup."Request Nos." := RequestNoSeriesCode;
        CollaborationSetup."Proposal Nos." := ProposalNoSeriesCode;
        CollaborationSetup."Default Response Days" := 7;
        CollaborationSetup."Portal Base URL" := 'https://portal.contoso.com';
        CollaborationSetup."Portal Support E-Mail" := 'support@contoso.com';
        CollaborationSetup."Link Validity Days" := 14;
        CollaborationSetup."Attach Order PDF" := false;
        CollaborationSetup.Validate(Enabled, true);
        CollaborationSetup.Modify(true);
    end;

    local procedure CreateNoSeriesCode(): Code[20]
    begin
        //todo: there is no function in standard tests libraries for this?
        exit(CopyStr('S' + DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure CreateNoSeries(NoSeriesCode: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        StartingNo: Code[20];
    begin
        //todo: there is no function in standard tests libraries for this?
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

    local procedure CreateVendor(CollaborationEnabled: Boolean): Code[20]
    var
        Vendor: Record Vendor;
        VendorNo: Code[20];
    begin
        //todo: there is no function in standard tests libraries for this?
        VendorNo := this.CreateRequestNo();
        Vendor.Init();
        Vendor."No." := VendorNo;
        Vendor.Name := VendorNo;
        Vendor."E-Mail" := 'vendor@contoso.com';
        Vendor."AMC Collaboration Enabled" := CollaborationEnabled;
        Vendor.Insert(false);
        exit(VendorNo);
    end;

    local procedure BindEmailSendHandler(var EmailSendHandler: Codeunit "AMC Email Send Test Handler"; EmailHandOffSucceeds: Boolean)
    begin
        EmailSendHandler.SetEmailHandOffResult(EmailHandOffSucceeds);
        BindSubscription(EmailSendHandler);
    end;

    local procedure UnbindEmailSendHandler(var EmailSendHandler: Codeunit "AMC Email Send Test Handler")
    begin
        UnbindSubscription(EmailSendHandler);
        EmailSendHandler.Reset();
    end;

    local procedure SendRequestWithEmailHandOff(var VendorRequest: Record "AMC Vendor Request"; EmailHandOffSucceeds: Boolean)
    var
        EmailSendHandler: Codeunit "AMC Email Send Test Handler";
        RequestMgt: Codeunit "AMC Request Mgt";
        LastErrorText: Text;
    begin
        this.BindEmailSendHandler(EmailSendHandler, EmailHandOffSucceeds);
        if this.TrySendRequest(VendorRequest, RequestMgt) then begin
            this.UnbindEmailSendHandler(EmailSendHandler);
            exit;
        end;

        LastErrorText := GetLastErrorText();
        this.UnbindEmailSendHandler(EmailSendHandler);
        Error(LastErrorText);
    end;

    [TryFunction]
    local procedure TrySendRequest(var VendorRequest: Record "AMC Vendor Request"; var RequestMgt: Codeunit "AMC Request Mgt")
    begin
        RequestMgt.Send(VendorRequest);
    end;

    local procedure CreateVendorWithLanguage(CollaborationEnabled: Boolean; LanguageCode: Code[10]): Code[20]
    var
        Vendor: Record Vendor;
        VendorNo: Code[20];
    begin
        VendorNo := this.CreateRequestNo();
        Vendor.Init();
        Vendor."No." := VendorNo;
        Vendor.Name := VendorNo;
        Vendor."E-Mail" := 'vendor@contoso.com';
        Vendor."Language Code" := LanguageCode;
        Vendor."AMC Collaboration Enabled" := CollaborationEnabled;
        Vendor.Insert(false);
        exit(VendorNo);
    end;

    local procedure GetAlternateLanguageCode(CompanyLanguageCode: Code[10]): Code[10]
    var
        LanguageRecord: Record Language;
    begin
        LanguageRecord.SetFilter(Code, '<>%1', CompanyLanguageCode);
        if LanguageRecord.FindFirst() then
            exit(LanguageRecord.Code);
    end;

    local procedure CreatePurchaseOrder(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; Status: Enum "Purchase Document Status")
    begin
        //todo: there is no function in standard tests libraries for this?
        this.EnsureCurrency('USD');
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
        PurchaseHeader."No." := this.CreateRequestNo();
        PurchaseHeader."Buy-from Vendor No." := VendorNo;
        PurchaseHeader."Purchaser Code" := 'BUYER';
        PurchaseHeader."Assigned User ID" := 'REQUESTOR';
        PurchaseHeader."Currency Code" := 'USD';
        PurchaseHeader.Status := Status;
        PurchaseHeader.Insert(false);
    end;

    local procedure EnsureCurrency(CurrencyCode: Code[10])
    var
        Currency: Record Currency;
    begin
        if Currency.Get(CurrencyCode) then
            exit;

        Currency.Init();
        Currency.Code := CurrencyCode;
        Currency.Description := CurrencyCode;
        Currency."Amount Rounding Precision" := 0.01;
        Currency."Unit-Amount Rounding Precision" := 0.00001;
        Currency.Insert(false);
    end;

    local procedure CreatePurchaseLine(PurchaseHeader: Record "Purchase Header"; LineNo: Integer; ItemNo: Code[20]; VariantCode: Code[10]; Description: Text[100]; LocationCode: Code[10]; UnitOfMeasureCode: Code[10]; Quantity: Decimal; RequestedReceiptDate: Date)
    var
        PurchaseLine: Record "Purchase Line";
    begin
        //todo: there is no function in standard tests libraries for this?
        PurchaseLine.Init();
        PurchaseLine."Document Type" := PurchaseHeader."Document Type";
        PurchaseLine."Document No." := PurchaseHeader."No.";
        PurchaseLine."Line No." := LineNo;
        PurchaseLine."No." := ItemNo;
        PurchaseLine."Variant Code" := VariantCode;
        PurchaseLine.Description := Description;
        PurchaseLine."Location Code" := LocationCode;
        PurchaseLine."Unit of Measure Code" := UnitOfMeasureCode;
        PurchaseLine.Quantity := Quantity;
        PurchaseLine."Requested Receipt Date" := RequestedReceiptDate;
        PurchaseLine.Insert(false);
    end;

    local procedure AssertRequestLine(RequestNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; VariantCode: Code[10]; Description: Text[100]; LocationCode: Code[10]; UnitOfMeasureCode: Code[10]; RequestedQuantity: Decimal; RequestedDeliveryDate: Date)
    var
        VendorRequestLine: Record "AMC Vendor Request Line";
    begin
        VendorRequestLine.Get(RequestNo, LineNo);
        this.Assert.AreEqual(LineNo, VendorRequestLine."Purchase Line No.", 'The request line must retain its source purchase line number.');
        this.Assert.AreEqual(ItemNo, VendorRequestLine."Item No.", 'The request line item must be snapshotted.');
        this.Assert.AreEqual(VariantCode, VendorRequestLine."Variant Code", 'The request line variant must be snapshotted.');
        this.Assert.AreEqual(Description, VendorRequestLine.Description, 'The request line description must be snapshotted.');
        this.Assert.AreEqual(LocationCode, VendorRequestLine."Location Code", 'The request line location must be snapshotted.');
        this.Assert.AreEqual(UnitOfMeasureCode, VendorRequestLine."Unit of Measure Code", 'The request line unit of measure must be snapshotted.');
        this.Assert.AreEqual(RequestedQuantity, VendorRequestLine."Requested Quantity", 'The request line quantity must be snapshotted.');
        this.Assert.AreEqual(RequestedDeliveryDate, VendorRequestLine."Requested Delivery Date", 'The request line requested receipt date must be snapshotted.');
        this.Assert.AreEqual(0, VendorRequestLine."Confirmed Quantity", 'The request line confirmed quantity must start at zero.');
        this.Assert.AreEqual(RequestedQuantity, VendorRequestLine."Outstanding Quantity", 'The request line outstanding quantity must equal the requested quantity.');
        this.Assert.AreEqual(VendorRequestLine.Status::Open, VendorRequestLine.Status, 'The request line must start as Open.');
    end;

    local procedure InsertVendorRequest(var VendorRequest: Record "AMC Vendor Request"; RequestNo: Code[20])
    begin
        VendorRequest.Init();
        VendorRequest."No." := RequestNo;
        VendorRequest.Insert();
    end;

    local procedure InsertVendorRequest(var VendorRequestLine: Record "AMC Vendor Request Line"; RequestNo: Code[20])
    begin
        VendorRequestLine.Init();
        VendorRequestLine."Request No." := RequestNo;
        VendorRequestLine."Line No." := 10000;
        VendorRequestLine.Insert();
    end;
}
