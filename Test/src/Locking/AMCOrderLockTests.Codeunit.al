namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Finance.Currency;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50141 "AMC Order Lock Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "AMC Test Library";
        PurchaseOrderLockedErr: Label 'Purchase order %1 is locked by active vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';

    [Test]
    procedure GivenLockedPurchaseOrder_WhenHeaderIsModified_ThenWriteIsBlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        RequestNo: Code[20];
    begin
        // Given
        this.CreateLockedPurchaseOrder(PurchaseHeader, RequestNo);
        PurchaseHeader.Validate("Your Reference", 'Changed reference');

        // When
        asserterror PurchaseHeader.Modify(true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));
    end;

    [Test]
    procedure GivenLockedPurchaseOrder_WhenOrderIsDeleted_ThenDeleteIsBlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        RequestNo: Code[20];
    begin
        // Given
        this.CreateLockedPurchaseOrder(PurchaseHeader, RequestNo);

        // When
        asserterror PurchaseHeader.Delete(true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));
    end;

    [Test]
    procedure GivenLockedPurchaseOrder_WhenLineIsChangedAddedOrDeleted_ThenWritesAreBlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        NewPurchaseLine: Record "Purchase Line";
        RequestNo: Code[20];
    begin
        // Given
        this.CreatePurchaseOrder(PurchaseHeader);
        this.CreatePurchaseLine(PurchaseHeader, 10000);
        NewPurchaseLine.Init();
        NewPurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
        NewPurchaseLine.Validate("Document No.", PurchaseHeader."No.");
        NewPurchaseLine.Validate("Line No.", 20000);
        NewPurchaseLine.Validate(Description, 'New line');
        this.LockPurchaseOrder(PurchaseHeader, RequestNo);
        Commit();
        PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000);
        PurchaseLine.Validate(Description, 'Changed description');

        // When
        asserterror PurchaseLine.Modify(true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));

        // When
        asserterror NewPurchaseLine.Insert(true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));

        // When
        asserterror PurchaseLine.Delete(true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));
    end;

    [Test]
    procedure GivenLockedPurchaseOrder_WhenReleased_ThenReleaseIsBlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        ReleasePurchaseDocument: Codeunit "Release Purchase Document";
        PurchaseOrderNo: Code[20];
        RequestNo: Code[20];
    begin
        // Given
        this.CreateLockedPurchaseOrder(PurchaseHeader, RequestNo);
        PurchaseOrderNo := PurchaseHeader."No.";
        Commit();

        // When
        asserterror ReleasePurchaseDocument.PerformManualRelease(PurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));

        // When
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseOrderNo);
        asserterror ReleasePurchaseDocument.ReleasePurchaseHeader(PurchaseHeader, false);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));
    end;

    [Test]
    procedure GivenLockedPurchaseOrder_WhenPosted_ThenPostingIsBlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchPost: Codeunit "Purch.-Post";
        RequestNo: Code[20];
    begin
        // Given
        this.CreateLockedPurchaseOrder(PurchaseHeader, RequestNo);

        // When
        asserterror PurchPost.Run(PurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseHeader."No.", RequestNo));
    end;

    [Test]
    procedure GivenUnlockedPurchaseOrder_WhenHeaderIsModified_ThenWriteIsPermitted()
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        // Given
        this.CreatePurchaseOrder(PurchaseHeader);
        PurchaseHeader.Validate("Your Reference", 'Changed reference');

        // When
        PurchaseHeader.Modify(true);

        // Then
        PurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.");
        this.Assert.AreEqual('Changed reference', PurchaseHeader."Your Reference", 'The unlocked purchase order header must be modifiable.');
    end;

    [Test]
    procedure GivenLockedPurchaseOrder_WhenMatchingSuppressionIsRestored_ThenOnlyMatchingWriteIsPermitted()
    var
        PurchaseHeader: Record "Purchase Header";
        PersistedPurchaseHeader: Record "Purchase Header";
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
        PreviousPurchaseOrderNo: Code[20];
        PreviousRequestNo: Code[20];
        PurchaseOrderNo: Code[20];
        RequestNo: Code[20];
    begin
        // Given
        this.CreateLockedPurchaseOrder(PurchaseHeader, RequestNo);
        PurchaseOrderNo := PurchaseHeader."No.";
        Commit();
        OrderLockMgt.SetSuppressionContext(PurchaseOrderNo, 'OTHER-REQUEST', PreviousPurchaseOrderNo, PreviousRequestNo);
        PersistedPurchaseHeader.Get(PersistedPurchaseHeader."Document Type"::Order, PurchaseOrderNo);

        // When
        asserterror OrderLockMgt.VerifyPurchaseHeaderCanBeModified(PersistedPurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));
        OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);

        // When
        OrderLockMgt.SetSuppressionContext('OTHER-ORDER', RequestNo, PreviousPurchaseOrderNo, PreviousRequestNo);
        PersistedPurchaseHeader.Get(PersistedPurchaseHeader."Document Type"::Order, PurchaseOrderNo);
        asserterror OrderLockMgt.VerifyPurchaseHeaderCanBeModified(PersistedPurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));
        OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);

        // When
        OrderLockMgt.SetSuppressionContext(PurchaseOrderNo, RequestNo, PreviousPurchaseOrderNo, PreviousRequestNo);
        PurchaseHeader.Validate("Your Reference", 'Suppressed reference');
        PurchaseHeader.Modify(true);
        PersistedPurchaseHeader.Get(PersistedPurchaseHeader."Document Type"::Order, PurchaseOrderNo);
        OrderLockMgt.VerifyPurchaseOrderCanBeReleased(PersistedPurchaseHeader);

        // Then
        this.Assert.AreEqual('Suppressed reference', PurchaseHeader."Your Reference", 'The matching suppression context must permit purchase order edits.');

        // When
        asserterror PurchaseHeader.Delete(true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));
        OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);

        // When
        PersistedPurchaseHeader.Get(PersistedPurchaseHeader."Document Type"::Order, PurchaseOrderNo);
        OrderLockMgt.SetSuppressionContext(PurchaseOrderNo, RequestNo, PreviousPurchaseOrderNo, PreviousRequestNo);
        asserterror OrderLockMgt.VerifyPurchaseOrderCanBePosted(PersistedPurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));
        OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
        PersistedPurchaseHeader.Get(PersistedPurchaseHeader."Document Type"::Order, PurchaseOrderNo);
        asserterror OrderLockMgt.VerifyPurchaseHeaderCanBeModified(PersistedPurchaseHeader);

        // Then
        this.Assert.ExpectedError(StrSubstNo(this.PurchaseOrderLockedErr, PurchaseOrderNo, RequestNo));
    end;

    [Test]
    procedure GivenInReviewRequest_WhenCancelled_ThenOrderIsUnlocked()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
    begin
        // Given
        this.CreateLockedPurchaseOrder(PurchaseHeader, RequestNo);
        VendorRequest.Get(RequestNo);
        RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"Vendor Responded");
        RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"In Review");

        // When
        RequestMgt.Cancel(PurchaseHeader);

        // Then
        PurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.");
        this.Assert.AreEqual('', PurchaseHeader."AMC Active Request No.", 'Cancelling the request must clear the active request from the purchase order.');
        VendorRequest.Get(RequestNo);
        this.Assert.AreEqual(VendorRequest.Status::Cancelled, VendorRequest.Status, 'Cancelling the request must set its status to Cancelled.');
    end;

    local procedure CreateLockedPurchaseOrder(var PurchaseHeader: Record "Purchase Header"; var RequestNo: Code[20])
    begin
        this.CreatePurchaseOrder(PurchaseHeader);
        this.LockPurchaseOrder(PurchaseHeader, RequestNo);
    end;

    local procedure CreatePurchaseOrder(var PurchaseHeader: Record "Purchase Header")
    var
        VendorNo: Code[20];
    begin
        this.EnsureCurrency('USD');
        this.TestLibrary.EnsureCurrencyExchangeRate('USD');
        VendorNo := this.CreateVendor();
        this.TestLibrary.CreatePurchaseOrder(PurchaseHeader, this.CreateRequestNo(), VendorNo);
        this.TestLibrary.EnsurePurchaser('BUYER');
        PurchaseHeader.Validate("Purchaser Code", 'BUYER');
        PurchaseHeader.Validate("Assigned User ID", UserId());
        PurchaseHeader.Validate("Currency Code", 'USD');
        PurchaseHeader.Validate(Status, PurchaseHeader.Status::Open);
        PurchaseHeader.Modify(false);
    end;

    local procedure CreateVendor(): Code[20]
    var
        Vendor: Record Vendor;
        VendorNo: Code[20];
    begin
        VendorNo := this.CreateRequestNo();
        this.TestLibrary.PrepareManualNumbering();
        Vendor.Init();
        Vendor.Validate("No.", VendorNo);
        Vendor.Validate(Name, VendorNo);
        Vendor.Validate("AMC Collaboration Enabled", true);
        Vendor.Insert(false);
        exit(VendorNo);
    end;

    local procedure EnsureCurrency(CurrencyCode: Code[10])
    var
        Currency: Record Currency;
    begin
        if Currency.Get(CurrencyCode) then
            exit;

        Currency.Init();
        Currency.Validate(Code, CurrencyCode);
        Currency.Validate(Description, CurrencyCode);
        Currency.Validate("Amount Rounding Precision", 0.01);
        Currency.Validate("Unit-Amount Rounding Precision", 0.00001);
        Currency.Insert(false);
    end;

    local procedure CreatePurchaseLine(PurchaseHeader: Record "Purchase Header"; LineNo: Integer)
    var
        PurchaseLine: Record "Purchase Line";
    begin
        PurchaseLine.Init();
        PurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.Validate("Document No.", PurchaseHeader."No.");
        PurchaseLine.Validate("Line No.", LineNo);
        PurchaseLine.Validate(Description, 'Purchase line');
        PurchaseLine.Insert(false);
    end;

    local procedure LockPurchaseOrder(var PurchaseHeader: Record "Purchase Header"; var RequestNo: Code[20])
    var
        VendorRequest: Record "AMC Vendor Request";
    begin
        RequestNo := this.CreateRequestNo();
        VendorRequest.Init();
        VendorRequest.Validate("No.", RequestNo);
        VendorRequest.Validate("Purchase Order No.", PurchaseHeader."No.");
        VendorRequest.Validate(Status, VendorRequest.Status::"Awaiting Vendor");
        VendorRequest.Insert(false);

        PurchaseHeader.Validate("AMC Active Request No.", RequestNo);
        PurchaseHeader.Validate("AMC Collaboration Status", VendorRequest.Status);
        PurchaseHeader.Modify(true);
    end;

    local procedure CreateRequestNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

}
