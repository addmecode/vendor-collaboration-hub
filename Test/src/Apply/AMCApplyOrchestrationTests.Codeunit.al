namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50134 "AMC Apply Orchestration Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenInReviewProposal_WhenApproved_ThenAuditIsPersistedAndOrderIsReleasedUnlockedAndRequestClosed()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorProposal: Record "AMC Vendor Proposal";
        VendorRequest: Record "AMC Vendor Request";
        VendorRequestLine: Record "AMC Vendor Request Line";
        VendorProposalLine: Record "AMC Vendor Proposal Line";
        DecisionSvc: Codeunit "AMC Proposal Decision Svc";
        ApplySucceeded: Boolean;
        ProposalNo: Code[20];
        ApprovalFailedErr: Label 'Approving the proposal failed: %1', Comment = '%1 = persisted apply error message';
    begin
        // Given
        this.CreateProposalForApply(PurchaseHeader, VendorProposal, ProposalNo);
        this.Assert.IsTrue(VendorProposalLine.Get(ProposalNo, 10000), 'The expected vendor proposal line record must exist.');
        VendorProposalLine.Validate("Line Type", VendorProposalLine."Line Type"::"Change Date");
        VendorProposalLine.Modify(false);
        Commit(); // Approval captures Codeunit.Run's result and must start without pending arrange writes.

        // When
        ApplySucceeded := DecisionSvc.Approve(VendorProposal, 'Approved for test.');
        if not ApplySucceeded then
            this.Assert.IsTrue(VendorProposal.Get(ProposalNo), 'The expected vendor proposal record must exist.');
        this.Assert.IsTrue(ApplySucceeded, StrSubstNo(ApprovalFailedErr, VendorProposal."Last Error Message"));

        // Then
        this.Assert.IsTrue(VendorProposal.Get(ProposalNo), 'The expected vendor proposal record must exist.');
        this.Assert.AreEqual(VendorProposal.Status::Applied, VendorProposal.Status, 'A successful decision must apply the proposal.');
        this.Assert.AreNotEqual(0DT, VendorProposal."Decision Date Time", 'A successful decision must be stamped.');
        this.Assert.AreEqual(UserId(), VendorProposal."Decision User ID", 'The decision audit must retain the full current user ID.');
        this.Assert.AreEqual('Approved for test.', VendorProposal."Decision Reason", 'A successful decision must retain its audit reason.');
        this.Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No."), 'The expected purchase header record must exist.');
        this.Assert.AreEqual(PurchaseHeader.Status::Released, PurchaseHeader.Status, 'Applying a proposal must release the purchase order.');
        this.Assert.AreEqual('', PurchaseHeader."AMC Active Request No.", 'Applying a proposal must unlock the purchase order.');
        this.Assert.IsTrue(VendorRequest.Get(VendorProposal."Request No."), 'The expected vendor request record must exist.');
        this.Assert.AreEqual(VendorRequest.Status::Closed, VendorRequest.Status, 'Applying a proposal must close its request.');
        this.Assert.IsTrue(VendorRequestLine.Get(VendorProposal."Request No.", 10000), 'The expected vendor request line record must exist.');
        this.Assert.AreEqual(10, VendorRequestLine."Confirmed Quantity", 'Applying a confirmed line must recalculate confirmed quantity.');
        this.Assert.AreEqual(0, VendorRequestLine."Outstanding Quantity", 'Applying a confirmed line must clear outstanding quantity.');
        this.Assert.AreEqual(VendorRequestLine.Status::Confirmed, VendorRequestLine.Status, 'A fully confirmed request line must have Confirmed status.');
        this.AssertProposalHasEntry(ProposalNo, "AMC Collab Entry Type"::ProposalApproved);
        this.AssertProposalHasEntry(ProposalNo, "AMC Collab Entry Type"::ProposalApplied);
        this.Assert.AreEqual(1, this.GetProposalEntryCount(ProposalNo, "AMC Collab Entry Type"::ProposalApplied), 'An applied line with no changed purchase values must still be audited.');
    end;

    [Test]
    procedure GivenInReviewProposal_WhenRejected_ThenItIsTerminalWithoutApplyingOrderChanges()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        VendorProposal: Record "AMC Vendor Proposal";
        DecisionSvc: Codeunit "AMC Proposal Decision Svc";
        ProposalNo: Code[20];
    begin
        // Given
        this.CreateProposalForApply(PurchaseHeader, VendorProposal, ProposalNo);
        Commit(); // Separate the in-review arrange baseline from the rejection's status and audit writes.

        // When
        DecisionSvc.Reject(VendorProposal, 'Rejected for test.');

        // Then
        this.Assert.IsTrue(VendorProposal.Get(ProposalNo), 'The expected vendor proposal record must exist.');
        this.Assert.AreEqual(VendorProposal.Status::Rejected, VendorProposal.Status, 'Rejecting must set a terminal rejected status.');
        this.Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No."), 'The expected purchase header record must exist.');
        this.Assert.AreEqual(PurchaseHeader.Status::Open, PurchaseHeader.Status, 'Rejecting must not release the purchase order.');
        this.Assert.AreNotEqual('', PurchaseHeader."AMC Active Request No.", 'Rejecting must not unlock the purchase order.');
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        this.Assert.AreEqual(1, PurchaseLine.Count(), 'Rejecting must not insert or remove purchase lines.');
        this.AssertProposalHasEntry(ProposalNo, "AMC Collab Entry Type"::ProposalRejected);
    end;

    [Test]
    procedure GivenDraftProposal_WhenApproved_ThenInvalidDecisionIsRejected()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorProposal: Record "AMC Vendor Proposal";
        DecisionSvc: Codeunit "AMC Proposal Decision Svc";
        ProposalNo: Code[20];
    begin
        // Given
        this.CreateProposalForApply(PurchaseHeader, VendorProposal, ProposalNo);
        VendorProposal.Validate(Status, VendorProposal.Status::Draft);
        VendorProposal.Modify(false);
        Commit(); // Preserve the Draft proposal fixture when the expected approval-validation error rolls back.

        // When
        asserterror DecisionSvc.Approve(VendorProposal, 'Invalid decision.');

        // Then
        this.Assert.IsTrue(StrPos(GetLastErrorText(), 'cannot be approved') > 0, 'Only an in-review or failed proposal can be approved.');
    end;

    [Test]
    procedure GivenNonApprovedContext_WhenApplyWorkerRuns_ThenApplyIsRejected()
    var
        TempDecisionContext: Record "AMC Vendor Proposal" temporary;
        PurchaseHeader: Record "Purchase Header";
        VendorProposal: Record "AMC Vendor Proposal";
        ApplySucceeded: Boolean;
        ProposalNo: Code[20];
    begin
        // Given
        this.CreateProposalForApply(PurchaseHeader, VendorProposal, ProposalNo);
        TempDecisionContext.Init();
        TempDecisionContext."No." := ProposalNo;
        TempDecisionContext.Status := TempDecisionContext.Status::"In Review";
        TempDecisionContext."Decision User ID" := CopyStr(UserId(), 1, MaxStrLen(TempDecisionContext."Decision User ID"));
        Commit(); // The Boolean Codeunit.Run call requires no pending writes and rolls back only the worker attempt.

        // When
        ApplySucceeded := Codeunit.Run(Codeunit::"AMC Apply Proposal Svc", TempDecisionContext);

        // Then
        this.Assert.IsFalse(ApplySucceeded, 'The apply worker must reject a context that does not represent an approval.');
        this.Assert.IsTrue(StrPos(GetLastErrorText(), 'VCH-APL-0001') > 0, 'The non-approved context must return the apply status error.');
    end;

    [Test]
    procedure GivenLateHandlerFailure_WhenProposalIsApproved_ThenEarlierWritesRollBackAndApplyFailureIsPersisted()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        VendorProposal: Record "AMC Vendor Proposal";
        VendorProposalLine: Record "AMC Vendor Proposal Line";
        DecisionSvc: Codeunit "AMC Proposal Decision Svc";
        OriginalPromisedReceiptDate: Date;
        ProposalNo: Code[20];
    begin
        // Given
        this.CreateProposalForApply(PurchaseHeader, VendorProposal, ProposalNo);
        this.Assert.IsTrue(PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000), 'The expected purchase line record must exist.');
        OriginalPromisedReceiptDate := PurchaseLine."Promised Receipt Date";
        this.Assert.IsTrue(VendorProposalLine.Get(ProposalNo, 10000), 'The expected vendor proposal line record must exist.');
        VendorProposalLine.Validate("Line Type", VendorProposalLine."Line Type"::"Change Date");
        VendorProposalLine.Validate("Proposed Delivery Date", WorkDate() + 10);
        VendorProposalLine.Modify(false);
        this.InsertUnknownProposalLine(ProposalNo, 20000, 2);
        Commit(); // Enter the Boolean Codeunit.Run worker without writes; preserve fixtures for rollback assertions.

        // When
        this.Assert.IsFalse(DecisionSvc.Approve(VendorProposal, 'Approve with deterministic failure.'), 'A later unknown handler must fail the atomic apply.');

        // Then
        this.Assert.IsTrue(VendorProposal.Get(ProposalNo), 'The expected vendor proposal record must exist.');
        this.Assert.AreEqual(VendorProposal.Status::"Apply Failed", VendorProposal.Status, 'A failed worker must persist Apply Failed after rollback.');
        this.Assert.AreNotEqual('', VendorProposal."Last Error Message", 'A failed worker must persist its error message.');
        this.Assert.IsTrue(StrPos(VendorProposal."Last Error Message", 'VCH-APL-0006') > 0, 'A failed unknown handler must preserve its domain error.');
        this.Assert.IsTrue(PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseHeader."No."), 'The expected purchase header record must exist.');
        this.Assert.AreEqual(PurchaseHeader.Status::Open, PurchaseHeader.Status, 'A failed worker must not release the purchase order.');
        this.Assert.AreNotEqual('', PurchaseHeader."AMC Active Request No.", 'A failed worker must keep the purchase order locked.');
        this.Assert.IsTrue(PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000), 'The expected purchase line record must exist.');
        this.Assert.AreEqual(OriginalPromisedReceiptDate, PurchaseLine."Promised Receipt Date", 'A later handler failure must roll back the earlier purchase-line mutation.');
        this.Assert.IsTrue(VendorProposalLine.Get(ProposalNo, 10000), 'The expected vendor proposal line record must exist.');
        this.Assert.IsFalse(VendorProposalLine.Applied, 'A later handler failure must roll back prior applied flags.');
        this.AssertProposalHasNoEntry(ProposalNo, "AMC Collab Entry Type"::ProposalApproved);
        this.AssertProposalHasEntry(ProposalNo, "AMC Collab Entry Type"::ProposalApplyFailed);
    end;

    [Test]
    procedure GivenApplyFailedProposal_WhenFailureIsCorrectedAndRetried_ThenItAppliesOnce()
    var
        PurchaseHeader: Record "Purchase Header";
        VendorProposal: Record "AMC Vendor Proposal";
        VendorProposalLine: Record "AMC Vendor Proposal Line";
        DecisionSvc: Codeunit "AMC Proposal Decision Svc";
        ApplySucceeded: Boolean;
        ProposalNo: Code[20];
        RetryFailedErr: Label 'Retrying the proposal failed: %1', Comment = '%1 = persisted apply error message';
    begin
        // Given
        this.CreateProposalForApply(PurchaseHeader, VendorProposal, ProposalNo);
        this.InsertUnknownProposalLine(ProposalNo, 20000, 2);
        Commit(); // End arrange writes before the first Boolean Codeunit.Run attempt and preserve its failure fixture.
        this.Assert.IsFalse(DecisionSvc.Approve(VendorProposal, 'First attempt fails.'), 'The first attempt must fail on the unknown handler.');
        this.Assert.IsTrue(VendorProposalLine.Get(ProposalNo, 20000), 'The expected vendor proposal line record must exist.');
        VendorProposalLine.Validate("Line Type", VendorProposalLine."Line Type"::Confirm);
        VendorProposalLine.Validate("Proposed Quantity", 10);
        VendorProposalLine.Validate("Proposed Delivery Date", WorkDate() + 1);
        VendorProposalLine.Modify(false);
        Commit(); // Persist failure bookkeeping and the corrected line before retrying the Boolean Codeunit.Run worker.

        // When
        ApplySucceeded := DecisionSvc.Approve(VendorProposal, 'Retry after correction.');
        if not ApplySucceeded then
            this.Assert.IsTrue(VendorProposal.Get(ProposalNo), 'The expected vendor proposal record must exist.');
        this.Assert.IsTrue(ApplySucceeded, StrSubstNo(RetryFailedErr, VendorProposal."Last Error Message"));

        // Then
        this.Assert.IsTrue(VendorProposal.Get(ProposalNo), 'The expected vendor proposal record must exist.');
        this.Assert.AreEqual(VendorProposal.Status::Applied, VendorProposal.Status, 'A corrected retry must apply the proposal.');
        this.Assert.AreEqual(2, VendorProposal."Apply Attempt Count", 'A retry must record exactly two attempts.');
    end;

    local procedure CreateProposalForApply(var PurchaseHeader: Record "Purchase Header"; var VendorProposal: Record "AMC Vendor Proposal"; var ProposalNo: Code[20])
    var
        PurchaseLine: Record "Purchase Line";
        Vendor: Record Vendor;
        VendorRequest: Record "AMC Vendor Request";
        VendorRequestLine: Record "AMC Vendor Request Line";
        TestLibrary: Codeunit "AMC Test Library";
        ItemNo: Code[20];
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        VendorNo := this.CreateIdentifier();
        ItemNo := this.CreateIdentifier();
        RequestNo := this.CreateIdentifier();
        ProposalNo := this.CreateIdentifier();

        //todo: can use standard libraries?
        TestLibrary.PrepareManualNumbering();
        Vendor.Init();
        Vendor.Validate("No.", VendorNo);
        Vendor.Validate(Name, VendorNo);
        Vendor.Insert(false);
        TestLibrary.EnsureItem(ItemNo, 'PCS');
        TestLibrary.CreatePurchaseOrder(PurchaseHeader, this.CreateIdentifier(), VendorNo);
        PurchaseLine.Init();
        PurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.Validate("Document No.", PurchaseHeader."No.");
        PurchaseLine.Validate("Line No.", 10000);
        PurchaseLine.Validate(Type, PurchaseLine.Type::Item);
        PurchaseLine.Validate("No.", ItemNo);
        PurchaseLine.Validate("Unit of Measure Code", 'PCS');
        PurchaseLine.Validate(Quantity, 10);
        PurchaseLine.Validate("Requested Receipt Date", WorkDate() + 1);
        PurchaseLine.Validate("Promised Receipt Date", WorkDate() + 1);
        PurchaseLine.Insert(false);
        VendorRequest.Init();
        VendorRequest.Validate("No.", RequestNo);
        VendorRequest.Validate("Vendor No.", VendorNo);
        VendorRequest.Validate("Purchase Order No.", PurchaseHeader."No.");
        VendorRequest.Validate(Status, VendorRequest.Status::"In Review");
        VendorRequest.Insert(false);
        VendorRequestLine.Init();
        VendorRequestLine.Validate("Request No.", RequestNo);
        VendorRequestLine.Validate("Line No.", 10000);
        VendorRequestLine.Validate("Purchase Line No.", PurchaseLine."Line No.");
        VendorRequestLine.Validate("Requested Quantity", PurchaseLine.Quantity);
        VendorRequestLine.Validate("Outstanding Quantity", PurchaseLine.Quantity);
        VendorRequestLine.Validate("Requested Delivery Date", PurchaseLine."Requested Receipt Date");
        VendorRequestLine.Validate(Status, VendorRequestLine.Status::Open);
        VendorRequestLine.Insert(false);
        PurchaseHeader.Validate("AMC Active Request No.", RequestNo);
        PurchaseHeader.Validate("AMC Collaboration Status", VendorRequest.Status);
        PurchaseHeader.Modify(false);
        VendorProposal.Init();
        VendorProposal.Validate("No.", ProposalNo);
        VendorProposal.Validate("Request No.", RequestNo);
        VendorProposal.Validate("Vendor No.", VendorNo);
        VendorProposal.Validate("Purchase Order No.", PurchaseHeader."No.");
        VendorProposal.Validate("Idempotency Key", ProposalNo);
        VendorProposal.Validate(Status, VendorProposal.Status::"In Review");
        VendorProposal.Insert(false);
        this.InsertProposalLine(ProposalNo, 10000, "AMC Proposal Line Type"::Confirm, 1);
    end;

    local procedure InsertUnknownProposalLine(ProposalNo: Code[20]; LineNo: Integer; SequenceNo: Integer)
    var
        VendorProposalLine: Record "AMC Vendor Proposal Line";
    begin
        VendorProposalLine.Init();
        VendorProposalLine.Validate("Proposal No.", ProposalNo);
        VendorProposalLine.Validate("Line No.", LineNo);
        VendorProposalLine.Validate("Request Line No.", 10000);
        VendorProposalLine.Validate("Line Type", Enum::"AMC Proposal Line Type".FromInteger(99));
        VendorProposalLine.Validate("Sequence No.", SequenceNo);
        VendorProposalLine.Validate("Proposed Quantity", 10);
        VendorProposalLine.Validate("Proposed Delivery Date", WorkDate() + 1);
        VendorProposalLine.Insert(false);
    end;

    local procedure InsertProposalLine(ProposalNo: Code[20]; LineNo: Integer; LineType: Enum "AMC Proposal Line Type"; SequenceNo: Integer)
    var
        VendorProposalLine: Record "AMC Vendor Proposal Line";
    begin
        VendorProposalLine.Init();
        VendorProposalLine.Validate("Proposal No.", ProposalNo);
        VendorProposalLine.Validate("Line No.", LineNo);
        VendorProposalLine.Validate("Request Line No.", 10000);
        VendorProposalLine.Validate("Line Type", LineType);
        VendorProposalLine.Validate("Sequence No.", SequenceNo);
        VendorProposalLine.Validate("Proposed Quantity", 10);
        VendorProposalLine.Validate("Proposed Delivery Date", WorkDate() + 1);
        VendorProposalLine.Insert(false);
    end;

    local procedure AssertProposalHasEntry(ProposalNo: Code[20]; EntryType: Enum "AMC Collab Entry Type")
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
    begin
        CollaborationEntry.SetRange("Source Type", CollaborationEntry."Source Type"::Proposal);
        CollaborationEntry.SetRange("Source No.", ProposalNo);
        CollaborationEntry.SetRange("Entry Type", EntryType);
        this.Assert.IsFalse(CollaborationEntry.IsEmpty(), 'The proposal decision must be recorded in the collaboration log.');
    end;

    local procedure GetProposalEntryCount(ProposalNo: Code[20]; EntryType: Enum "AMC Collab Entry Type"): Integer
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
    begin
        CollaborationEntry.SetRange("Source Type", CollaborationEntry."Source Type"::Proposal);
        CollaborationEntry.SetRange("Source No.", ProposalNo);
        CollaborationEntry.SetRange("Entry Type", EntryType);
        exit(CollaborationEntry.Count());
    end;

    local procedure AssertProposalHasNoEntry(ProposalNo: Code[20]; EntryType: Enum "AMC Collab Entry Type")
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
    begin
        CollaborationEntry.SetRange("Source Type", CollaborationEntry."Source Type"::Proposal);
        CollaborationEntry.SetRange("Source No.", ProposalNo);
        CollaborationEntry.SetRange("Entry Type", EntryType);
        this.Assert.IsTrue(CollaborationEntry.IsEmpty(), 'A rolled-back worker must not leave success audit entries.');
    end;

    local procedure CreateIdentifier(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;
}
