namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Finance.Dimension;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50138 "AMC Split Delivery Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";
    TestLibrary: Codeunit "AMC Test Library";

  [Test]
  procedure GivenTwoSplitProposals_WhenSplitDeliveryIsApplied_ThenLinesHaveQuantitiesDatesDimensionsAndOriginStamps()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    FirstProposalLine: Record "AMC Vendor Proposal Line";
    SecondProposalLine: Record "AMC Vendor Proposal Line";
    SplitPurchaseLine: Record "Purchase Line";
    SplitDeliveryHandler: Codeunit "AMC Split Delivery Handler";
    FirstDate: Date;
    SecondDate: Date;
  begin
    // Given
    FirstDate := WorkDate() + 7;
    SecondDate := WorkDate() + 14;
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, FirstProposalLine, SecondProposalLine, false);
    FirstProposalLine.Validate("Proposed Quantity", 600);
    FirstProposalLine.Validate("Proposed Delivery Date", FirstDate);
    FirstProposalLine.Modify(false);
    SecondProposalLine.Validate("Proposed Quantity", 400);
    SecondProposalLine.Validate("Proposed Delivery Date", SecondDate);
    SecondProposalLine.Modify(false);

    // When
    SplitDeliveryHandler.Apply(FirstProposalLine, PurchaseHeader);
    SplitDeliveryHandler.Apply(SecondProposalLine, PurchaseHeader);

    // Then
    this.Assert.IsTrue(PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000), 'The expected purchase line record must exist.');
    this.Assert.IsTrue(SplitPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 15000), 'The expected split purchase line record must exist.');
    this.Assert.AreEqual(600, PurchaseLine.Quantity, 'The first split must update the origin quantity.');
    this.Assert.AreEqual(FirstDate, PurchaseLine."Promised Receipt Date", 'The first split must update the origin promised date.');
    this.Assert.AreEqual(FirstProposalLine."Proposal No.", PurchaseLine."AMC Origin Proposal No.", 'The origin line must be stamped with the first split proposal.');
    this.Assert.AreEqual(400, SplitPurchaseLine.Quantity, 'The later split must create the remaining quantity.');
    this.Assert.AreEqual(SecondDate, SplitPurchaseLine."Promised Receipt Date", 'The later split must use its proposed delivery date.');
    this.Assert.IsTrue(PurchaseLine."Dimension Set ID" > 0, 'The source must contain a real dimension set before its dimensions are copied.');
    this.Assert.AreEqual(PurchaseLine."Dimension Set ID", SplitPurchaseLine."Dimension Set ID", 'The split line must copy the origin dimensions.');
    this.Assert.AreEqual(SecondProposalLine."Proposal No.", SplitPurchaseLine."AMC Origin Proposal No.", 'The split line must be stamped with its proposal.');
    this.Assert.AreEqual(SecondProposalLine."Line No.", SplitPurchaseLine."AMC Origin Proposal Line No.", 'The split line must be stamped with its proposal line.');
  end;

  [Test]
  procedure GivenNoFreeLineNumber_WhenLaterSplitIsApplied_ThenNoGapErrorIsRaisedWithoutRenumbering()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    FirstProposalLine: Record "AMC Vendor Proposal Line";
    SecondProposalLine: Record "AMC Vendor Proposal Line";
    ExistingPurchaseLine: Record "Purchase Line";
    SplitPurchaseLine: Record "Purchase Line";
    SplitDeliveryHandler: Codeunit "AMC Split Delivery Handler";
    ApplySucceeded: Boolean;
    ErrorText: Text;
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, FirstProposalLine, SecondProposalLine, true);
    FirstProposalLine.Validate("Proposed Quantity", 600);
    FirstProposalLine.Validate("Proposed Delivery Date", WorkDate() + 7);
    FirstProposalLine.Modify(false);
    SecondProposalLine.Validate("Proposed Quantity", 400);
    SecondProposalLine.Validate("Proposed Delivery Date", WorkDate() + 14);
    SecondProposalLine.Modify(false);
    SplitDeliveryHandler.Apply(FirstProposalLine, PurchaseHeader);

    // When
    ApplySucceeded := this.TryApplySplit(SecondProposalLine, PurchaseHeader);
    ErrorText := GetLastErrorText();

    // Then
    this.Assert.IsFalse(ApplySucceeded, 'A later split without a free line number must fail.');
    this.Assert.IsTrue(StrPos(ErrorText, 'VCH-APL-0005') > 0, 'The no-gap failure must use the controlled application error code.');
    this.Assert.IsTrue(ExistingPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10001), 'The expected existing purchase line record must exist.');
    this.Assert.AreEqual(10001, ExistingPurchaseLine."Line No.", 'The existing adjacent line must not be renumbered.');
    this.Assert.IsFalse(SplitPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 15000), 'No split line must be inserted when no gap is available.');
  end;

  [TryFunction]
  local procedure TryApplySplit(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    SplitDeliveryHandler: Codeunit "AMC Split Delivery Handler";
  begin
    SplitDeliveryHandler.Apply(ProposalLine, PurchaseHeader);
  end;

  local procedure CreateSourceRecords(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; var FirstProposalLine: Record "AMC Vendor Proposal Line"; var SecondProposalLine: Record "AMC Vendor Proposal Line"; CreateAdjacentLine: Boolean)
  var
    AdjacentPurchaseLine: Record "Purchase Line";
    Vendor: Record Vendor;
    VendorProposal: Record "AMC Vendor Proposal";
    VendorRequest: Record "AMC Vendor Request";
    RequestLine: Record "AMC Vendor Request Line";
    TempDimensionSetEntry: Record "Dimension Set Entry" temporary;
    Dimension: Record Dimension;
    DimensionValue: Record "Dimension Value";
    DimensionManagement: Codeunit DimensionManagement;
    DimensionCode: Code[20];
    DimensionValueCode: Code[20];
    ProposalNo: Code[20];
    PurchaseOrderNo: Code[20];
    RequestNo: Code[20];
    VendorNo: Code[20];
  begin
    ProposalNo := this.CreateIdentifier();
    PurchaseOrderNo := this.CreateIdentifier();
    RequestNo := this.CreateIdentifier();
    VendorNo := this.CreateIdentifier();
    DimensionCode := this.CreateIdentifier();
    DimensionValueCode := this.CreateIdentifier();
    Dimension.Init();
    Dimension.Validate(Code, DimensionCode);
    Dimension.Validate(Name, DimensionCode);
    Dimension.Insert(false);
    DimensionValue.Init();
    DimensionValue.Validate("Dimension Code", DimensionCode);
    DimensionValue.Validate(Code, DimensionValueCode);
    DimensionValue.Validate(Name, DimensionValueCode);
    DimensionValue.Insert(false);
    TempDimensionSetEntry.Init();
    // Copy the freshly created valid value, including the ID normally set by field validation.
    TempDimensionSetEntry."Dimension Code" := DimensionValue."Dimension Code";
    TempDimensionSetEntry."Dimension Value Code" := DimensionValue.Code;
    TempDimensionSetEntry."Dimension Value ID" := DimensionValue."Dimension Value ID";
    TempDimensionSetEntry.Insert(false);
    this.TestLibrary.PrepareManualNumbering();
    Vendor.Init();
    Vendor.Validate("No.", VendorNo);
    Vendor.Validate(Name, VendorNo);
    Vendor.Insert(false);
    this.TestLibrary.CreatePurchaseOrder(PurchaseHeader, PurchaseOrderNo, VendorNo);
    PurchaseLine.Init();
    PurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
    PurchaseLine.Validate("Document No.", PurchaseHeader."No.");
    PurchaseLine.Validate("Line No.", 10000);
    PurchaseLine.Validate(Quantity, 1000);
    PurchaseLine.Validate("Dimension Set ID", DimensionManagement.GetDimensionSetID(TempDimensionSetEntry));
    PurchaseLine.Insert(false);
    AdjacentPurchaseLine.Init();
    AdjacentPurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
    AdjacentPurchaseLine.Validate("Document No.", PurchaseHeader."No.");
    if CreateAdjacentLine then
      AdjacentPurchaseLine.Validate("Line No.", 10001)
    else
      AdjacentPurchaseLine.Validate("Line No.", 20000);
    AdjacentPurchaseLine.Insert(false);
    VendorRequest.Init();
    VendorRequest.Validate("No.", RequestNo);
    VendorRequest.Validate("Vendor No.", VendorNo);
    VendorRequest.Validate("Purchase Order No.", PurchaseOrderNo);
    VendorRequest.Insert(false);
    RequestLine.Init();
    RequestLine.Validate("Request No.", RequestNo);
    RequestLine.Validate("Line No.", 10000);
    RequestLine.Validate("Purchase Line No.", PurchaseLine."Line No.");
    RequestLine.Insert(false);
    VendorProposal.Init();
    VendorProposal.Validate("No.", ProposalNo);
    VendorProposal.Validate("Request No.", RequestNo);
    VendorProposal.Validate("Vendor No.", VendorNo);
    VendorProposal.Validate("Purchase Order No.", PurchaseOrderNo);
    VendorProposal.Validate("Idempotency Key", ProposalNo);
    VendorProposal.Insert(false);
    this.CreateProposalLine(FirstProposalLine, ProposalNo, 10000, 1);
    this.CreateProposalLine(SecondProposalLine, ProposalNo, 20000, 2);
  end;

  local procedure CreateProposalLine(var ProposalLine: Record "AMC Vendor Proposal Line"; ProposalNo: Code[20]; LineNo: Integer; SequenceNo: Integer)
  begin
    ProposalLine.Init();
    ProposalLine.Validate("Proposal No.", ProposalNo);
    ProposalLine.Validate("Line No.", LineNo);
    ProposalLine.Validate("Request Line No.", 10000);
    ProposalLine.Validate("Line Type", ProposalLine."Line Type"::"Split Delivery");
    ProposalLine.Validate("Sequence No.", SequenceNo);
    ProposalLine.Insert(false);
  end;

  local procedure CreateIdentifier(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
