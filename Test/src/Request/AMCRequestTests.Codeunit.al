namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Foundation.NoSeries;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
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
    procedure GivenCreatedRequest_WhenSourcePurchaseLineChanges_ThenRequestLineSnapshotRemainsUnchanged()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        VendorRequestLine: Record "AMC Vendor Request Line";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        this.ConfigureEnabledSetup();
        VendorNo := this.CreateVendor(true);
        this.CreatePurchaseOrder(PurchaseHeader, VendorNo, PurchaseHeader.Status::Open);
        this.CreatePurchaseLine(PurchaseHeader, 10000, 'ITEM-ONE', '', 'Original description', 'MAIN', 'PCS', 10, 20260915D);
        RequestNo := RequestMgt.CreateFromOrder(PurchaseHeader);
        PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000);
        PurchaseLine.Description := 'Changed description';

        // When
        PurchaseLine.Modify(true);

        // Then
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

    local procedure CreateRequestNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
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
        CollaborationSetup."Portal Base URL" := 'https://portal.contoso.com';
        CollaborationSetup."Portal Support E-Mail" := 'support@contoso.com';
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
        Vendor."AMC Collaboration Enabled" := CollaborationEnabled;
        Vendor.Insert(false);
        exit(VendorNo);
    end;

    local procedure CreatePurchaseOrder(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; Status: Enum "Purchase Document Status")
    begin
        //todo: there is no function in standard tests libraries for this?
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
