namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Foundation.NoSeries;
using System.TestLibraries.Utilities;

codeunit 50133 "AMC Proposal Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenVendorRequest_WhenCreateDraftFromRequest_ThenDraftCopiesRequestIdentity()
    var
        VendorProposal: Record "AMC Vendor Proposal";
        SecondVendorProposal: Record "AMC Vendor Proposal";
        VendorRequest: Record "AMC Vendor Request";
        ProposalMgt: Codeunit "AMC Proposal Mgt";
        ProposalNo: Code[20];
        RequestNo: Code[20];
        SecondProposalNo: Code[20];
    begin
        // Given
        this.ConfigureProposalNoSeries();
        RequestNo := this.CreateRequest('VENDOR-ONE', 'PO-ONE');
        VendorRequest.Get(RequestNo);

        // When
        ProposalNo := ProposalMgt.CreateDraftFromRequest(VendorRequest);
        SecondProposalNo := ProposalMgt.CreateDraftFromRequest(VendorRequest);

        // Then
        VendorProposal.Get(ProposalNo);
        this.Assert.AreEqual(RequestNo, VendorProposal."Request No.", 'The draft must refer to the selected request.');
        this.Assert.AreEqual(VendorRequest."Vendor No.", VendorProposal."Vendor No.", 'The draft must copy the vendor from the request.');
        this.Assert.AreEqual(VendorRequest."Purchase Order No.", VendorProposal."Purchase Order No.", 'The draft must copy the purchase order from the request.');
        this.Assert.AreEqual(VendorProposal.Status::Draft, VendorProposal.Status, 'A manually created proposal must start as Draft.');
        this.Assert.AreNotEqual('', VendorProposal."Idempotency Key", 'A manually created draft must have an internal idempotency key.');
        SecondVendorProposal.Get(SecondProposalNo);
        this.Assert.AreNotEqual(VendorProposal."Idempotency Key", SecondVendorProposal."Idempotency Key", 'Each manually created draft must have a distinct internal idempotency key.');
    end;

    [Test]
    procedure GivenSameVendorAndIdempotencyKey_WhenSecondProposalIsInserted_ThenItIsRejectedButAnotherVendorIsAllowed()
    var
        DuplicateProposal: Record "AMC Vendor Proposal";
        OtherVendorProposal: Record "AMC Vendor Proposal";
        VendorProposal: Record "AMC Vendor Proposal";
        RequestNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateRequest('VENDOR-FOUR', 'PO-FOUR');
        this.InsertProposal(VendorProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-FOUR', 'PO-FOUR', 'duplicate-key', VendorProposal.Status::Draft);

        // When
        asserterror this.InsertProposal(DuplicateProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-FOUR', 'PO-FOUR', 'duplicate-key', DuplicateProposal.Status::Draft);
        this.Assert.IsTrue(StrPos(GetLastErrorText(), 'duplicate-key') > 0, 'The duplicate-key error must identify the duplicate idempotency key.');
        this.InsertProposal(OtherVendorProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-FIVE', 'PO-FOUR', 'duplicate-key', OtherVendorProposal.Status::Draft);

        // Then
        OtherVendorProposal.Get(OtherVendorProposal."No.");
        this.Assert.AreEqual('VENDOR-FIVE', OtherVendorProposal."Vendor No.", 'The same idempotency key must be allowed for a different vendor.');
    end;

    [Test]
    procedure GivenProposalWithLines_WhenProposalIsDeleted_ThenItsLinesAreDeleted()
    var
        VendorProposal: Record "AMC Vendor Proposal";
        VendorProposalLine: Record "AMC Vendor Proposal Line";
        ProposalNo: Code[20];
        RequestNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateRequest('VENDOR-SIX', 'PO-SIX');
        ProposalNo := this.CreateDraft(RequestNo);
        this.InsertProposalLine(ProposalNo, 10000, 10000, VendorProposalLine."Line Type"::Confirm, 1, '', '', 10, 20260915D, '');
        VendorProposal.Get(ProposalNo);

        // When
        VendorProposal.Delete(true);

        // Then
        VendorProposalLine.SetRange("Proposal No.", ProposalNo);
        this.Assert.IsTrue(VendorProposalLine.IsEmpty(), 'Deleting a proposal must delete its lines.');
    end;

    [Test]
    procedure GivenProposalsInDifferentStatuses_WhenOpenProposalCountIsCalculated_ThenOnlySubmittedAndInReviewAreCounted()
    var
        VendorProposal: Record "AMC Vendor Proposal";
        VendorRequest: Record "AMC Vendor Request";
        RequestNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateRequest('VENDOR-SEVEN', 'PO-SEVEN');
        this.InsertProposal(VendorProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-SEVEN', 'PO-SEVEN', 'draft-key', VendorProposal.Status::Draft);
        this.InsertProposal(VendorProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-SEVEN', 'PO-SEVEN', 'submitted-key', VendorProposal.Status::Submitted);
        this.InsertProposal(VendorProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-SEVEN', 'PO-SEVEN', 'review-key', VendorProposal.Status::"In Review");
        this.InsertProposal(VendorProposal, this.CreateIdentifier(), RequestNo, 'VENDOR-SEVEN', 'PO-SEVEN', 'applied-key', VendorProposal.Status::Applied);
        VendorRequest.Get(RequestNo);

        // When
        VendorRequest.CalcFields("Open Proposal Count");

        // Then
        this.Assert.AreEqual(2, VendorRequest."Open Proposal Count", 'Only Submitted and In Review proposals must count as open.');
    end;

    [Test]
    procedure GivenQuantityAboveOutstanding_WhenProposalIsValidated_ThenQuantityErrorIsReturned()
    var
        ValidationResult: Codeunit "AMC Validation Result";
        ProposalValidator: Codeunit "AMC Proposal Validator";
        ProposalNo: Code[20];
    begin
        // Given
        this.ConfigureValidationSetup(false, 3, false);
        ProposalNo := this.CreateValidationProposal(10);
        this.InsertProposalLine(ProposalNo, 10000, 10000, "AMC Proposal Line Type"::Confirm, 1, '', '', 11, WorkDate(), '');

        // When
        ProposalValidator.Validate(this.GetProposal(ProposalNo), ValidationResult);

        // Then
        this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'A quantity above the outstanding quantity must be rejected.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0012') > 0, 'The quantity error code must be returned.');
    end;

    [Test]
    procedure GivenPastDeliveryDate_WhenProposalIsValidated_ThenDateErrorIsReturned()
    var
        ValidationResult: Codeunit "AMC Validation Result";
        ProposalValidator: Codeunit "AMC Proposal Validator";
        ProposalNo: Code[20];
    begin
        // Given
        this.ConfigureValidationSetup(false, 3, false);
        ProposalNo := this.CreateValidationProposal(10);
        this.InsertProposalLine(ProposalNo, 10000, 10000, "AMC Proposal Line Type"::Confirm, 1, '', '', 10, WorkDate() - 1, '');

        // When
        ProposalValidator.Validate(this.GetProposal(ProposalNo), ValidationResult);

        // Then
        this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'A past delivery date must be rejected.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0020') > 0, 'The past-date error code must be returned.');
    end;

    [Test]
    procedure GivenUnregisteredSubstitute_WhenProposalIsValidated_ThenSubstitutionErrorIsReturned()
    var
        ValidationResult: Codeunit "AMC Validation Result";
        ProposalValidator: Codeunit "AMC Proposal Validator";
        ProposalNo: Code[20];
    begin
        // Given
        this.ConfigureValidationSetup(true, 3, false);
        ProposalNo := this.CreateValidationProposal(10);
        this.InsertProposalLine(ProposalNo, 10000, 10000, "AMC Proposal Line Type"::"Substitute Item", 1, 'SUBSTITUTE', '', 10, WorkDate(), '');

        // When
        ProposalValidator.Validate(this.GetProposal(ProposalNo), ValidationResult);

        // Then
        this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'An unregistered substitute must be rejected.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0030') > 0, 'The substitution error code must be returned.');
    end;

    [Test]
    procedure GivenTooManySplits_WhenProposalIsValidated_ThenSplitCountErrorIsReturned()
    var
        ValidationResult: Codeunit "AMC Validation Result";
        ProposalValidator: Codeunit "AMC Proposal Validator";
        ProposalNo: Code[20];
    begin
        // Given
        this.ConfigureValidationSetup(false, 1, false);
        ProposalNo := this.CreateValidationProposal(10);
        this.InsertProposalLine(ProposalNo, 10000, 10000, "AMC Proposal Line Type"::"Split Delivery", 1, '', '', 5, WorkDate(), '');
        this.InsertProposalLine(ProposalNo, 20000, 10000, "AMC Proposal Line Type"::"Split Delivery", 2, '', '', 5, WorkDate(), '');

        // When
        ProposalValidator.Validate(this.GetProposal(ProposalNo), ValidationResult);

        // Then
        this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'Too many splits must be rejected.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0031') > 0, 'The split-count error code must be returned.');
    end;

    [Test]
    procedure GivenMissingReasonCode_WhenProposalIsValidated_ThenReasonErrorIsReturned()
    var
        ValidationResult: Codeunit "AMC Validation Result";
        ProposalValidator: Codeunit "AMC Proposal Validator";
        ProposalNo: Code[20];
    begin
        // Given
        this.ConfigureValidationSetup(false, 3, true);
        ProposalNo := this.CreateValidationProposal(10);
        this.InsertProposalLine(ProposalNo, 10000, 10000, "AMC Proposal Line Type"::"Change Date", 1, '', '', 10, WorkDate(), '');

        // When
        ProposalValidator.Validate(this.GetProposal(ProposalNo), ValidationResult);

        // Then
        this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'A missing required reason code must be rejected.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0040') > 0, 'The reason-code error must be returned.');
    end;

    [Test]
    procedure GivenThreeInvalidValues_WhenProposalIsValidated_ThenAllErrorsAreReturned()
    var
        ValidationResult: Codeunit "AMC Validation Result";
        ProposalValidator: Codeunit "AMC Proposal Validator";
        ProposalNo: Code[20];
    begin
        // Given
        this.ConfigureValidationSetup(false, 3, true);
        ProposalNo := this.CreateValidationProposal(10);
        this.InsertProposalLine(ProposalNo, 10000, 10000, "AMC Proposal Line Type"::"Change Date", 1, '', '', 11, WorkDate() - 1, '');

        // When
        ProposalValidator.Validate(this.GetProposal(ProposalNo), ValidationResult);

        // Then
        this.Assert.AreEqual(3, ValidationResult.GetErrorCount(), 'Validation must collect every independent failure.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0012') > 0, 'Text validation output must include the quantity error.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0020') > 0, 'Text validation output must include the date error.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0040') > 0, 'Text validation output must include the reason error.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsJson(), 'VCH-VAL-0012') > 0, 'JSON validation output must include the quantity error.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsJson(), 'VCH-VAL-0020') > 0, 'JSON validation output must include the date error.');
        this.Assert.IsTrue(StrPos(ValidationResult.AsJson(), 'VCH-VAL-0040') > 0, 'JSON validation output must include the reason error.');
    end;

    local procedure ConfigureProposalNoSeries()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        ProposalNoSeriesCode: Code[20];
    begin
        ProposalNoSeriesCode := this.CreateIdentifier();
        this.CreateNoSeries(ProposalNoSeriesCode);
        CollaborationSetup.GetSetup();
        CollaborationSetup."Proposal Nos." := ProposalNoSeriesCode;
        CollaborationSetup.Modify(true);
    end;

    local procedure ConfigureValidationSetup(AllowItemSubstitution: Boolean; MaxSplitsPerLine: Integer; RequireReasonCode: Boolean)
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        CollaborationSetup.GetSetup();
        CollaborationSetup."Allow Item Substitution" := AllowItemSubstitution;
        CollaborationSetup."Max Splits per Line" := MaxSplitsPerLine;
        CollaborationSetup."Require Reason Code" := RequireReasonCode;
        CollaborationSetup.Modify(false);
    end;

    local procedure CreateValidationProposal(OutstandingQuantity: Decimal): Code[20]
    var
        VendorProposal: Record "AMC Vendor Proposal";
        VendorRequestLine: Record "AMC Vendor Request Line";
        ProposalNo: Code[20];
        RequestNo: Code[20];
    begin
        RequestNo := this.CreateRequest('VALIDATION-VENDOR', 'VALIDATION-ORDER');
        ProposalNo := this.CreateIdentifier();
        this.InsertProposal(VendorProposal, ProposalNo, RequestNo, 'VALIDATION-VENDOR', 'VALIDATION-ORDER', this.CreateIdentifier(), VendorProposal.Status::Draft);

        VendorRequestLine.Init();
        VendorRequestLine."Request No." := RequestNo;
        VendorRequestLine."Line No." := 10000;
        VendorRequestLine."Item No." := 'REQUESTED';
        VendorRequestLine."Outstanding Quantity" := OutstandingQuantity;
        VendorRequestLine.Insert(false);

        exit(ProposalNo);
    end;

    local procedure GetProposal(ProposalNo: Code[20]) VendorProposal: Record "AMC Vendor Proposal"
    begin
        VendorProposal.Get(ProposalNo);
    end;

    local procedure CreateNoSeries(NoSeriesCode: Code[20])
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        StartingNo: Code[20];
    begin
        //todo: use standard library
        StartingNo := CopyStr('P' + DelChr(Format(CreateGuid()), '=', '{}-') + '1', 1, 20);
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

    local procedure CreateRequest(VendorNo: Code[20]; PurchaseOrderNo: Code[20]): Code[20]
    var
        VendorRequest: Record "AMC Vendor Request";
        RequestNo: Code[20];
    begin
        RequestNo := this.CreateIdentifier();
        VendorRequest.Init();
        VendorRequest."No." := RequestNo;
        VendorRequest."Vendor No." := VendorNo;
        VendorRequest."Purchase Order No." := PurchaseOrderNo;
        VendorRequest.Insert(false);

        exit(RequestNo);
    end;

    local procedure CreateDraft(RequestNo: Code[20]): Code[20]
    var
        VendorRequest: Record "AMC Vendor Request";
        ProposalMgt: Codeunit "AMC Proposal Mgt";
    begin
        this.ConfigureProposalNoSeries();
        VendorRequest.Get(RequestNo);
        exit(ProposalMgt.CreateDraftFromRequest(VendorRequest));
    end;

    local procedure CreateIdentifier(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure InsertProposal(var VendorProposal: Record "AMC Vendor Proposal"; ProposalNo: Code[20]; RequestNo: Code[20]; VendorNo: Code[20]; PurchaseOrderNo: Code[20]; IdempotencyKey: Text[64]; Status: Enum "AMC Proposal Status")
    begin
        VendorProposal.Init();
        VendorProposal."No." := ProposalNo;
        VendorProposal."Request No." := RequestNo;
        VendorProposal."Vendor No." := VendorNo;
        VendorProposal."Purchase Order No." := PurchaseOrderNo;
        VendorProposal."Idempotency Key" := IdempotencyKey;
        VendorProposal.Status := Status;
        VendorProposal.Insert(true);
    end;

    local procedure InsertProposalLine(ProposalNo: Code[20]; LineNo: Integer; RequestLineNo: Integer; LineType: Enum "AMC Proposal Line Type"; SequenceNo: Integer; ProposedItemNo: Code[20]; ProposedVariantCode: Code[10]; ProposedQuantity: Decimal; ProposedDeliveryDate: Date; ReasonCode: Code[10])
    var
        VendorProposalLine: Record "AMC Vendor Proposal Line";
    begin
        VendorProposalLine.Init();
        VendorProposalLine."Proposal No." := ProposalNo;
        VendorProposalLine."Line No." := LineNo;
        VendorProposalLine."Request Line No." := RequestLineNo;
        VendorProposalLine."Line Type" := LineType;
        VendorProposalLine."Sequence No." := SequenceNo;
        VendorProposalLine."Proposed Item No." := ProposedItemNo;
        VendorProposalLine."Proposed Variant Code" := ProposedVariantCode;
        VendorProposalLine."Proposed Quantity" := ProposedQuantity;
        VendorProposalLine."Proposed Delivery Date" := ProposedDeliveryDate;
        VendorProposalLine."Reason Code" := ReasonCode;
        VendorProposalLine.Insert(false);
    end;
}
