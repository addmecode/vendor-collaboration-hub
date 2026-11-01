namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50137 "AMC Change Date Handler Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";
    TestLibrary: Codeunit "AMC Test Library";

  [Test]
  procedure GivenProposedDeliveryDate_WhenChangeDateIsApplied_ThenPurchaseLinePromisedDateIsChanged()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    ChangeDateHandler: Codeunit "AMC Change Date Handler";
    ProposedDate: Date;
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine);
    ProposedDate := WorkDate() + 7;
    ProposalLine.Validate("Proposed Delivery Date", ProposedDate);
    ProposalLine.Modify(false);

    // When
    ChangeDateHandler.Apply(ProposalLine, PurchaseHeader);

    // Then
    this.Assert.IsTrue(PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseLine."Line No."), 'The expected purchase line record must exist.');
    this.Assert.AreEqual(ProposedDate, PurchaseLine."Promised Receipt Date", 'Applying a date change must update the promised receipt date.');
  end;

  [Test]
  procedure GivenPastProposedDeliveryDate_WhenChangeDateIsApplied_ThenHandlerRejectsWithoutChangingPurchaseLine()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    ApplySucceeded: Boolean;
    ErrorText: Text;
    OriginalPromisedDate: Date;
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine);
    OriginalPromisedDate := WorkDate() + 3;
    PurchaseLine.Validate("Promised Receipt Date", OriginalPromisedDate);
    PurchaseLine.Modify(false);
    ProposalLine.Validate("Proposed Delivery Date", WorkDate() - 1);
    ProposalLine.Modify(false);

    // When
    ApplySucceeded := this.TryApplyChangeDate(ProposalLine, PurchaseHeader);
    ErrorText := GetLastErrorText();

    // Then
    this.Assert.IsFalse(ApplySucceeded, 'A past proposed delivery date must be rejected.');
    this.Assert.IsTrue(StrPos(ErrorText, 'VCH-VAL-0020') > 0, 'A past proposed delivery date must return the delivery date validation code.');
    this.Assert.IsTrue(PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseLine."Line No."), 'The expected purchase line record must exist.');
    this.Assert.AreEqual(OriginalPromisedDate, PurchaseLine."Promised Receipt Date", 'A rejected date change must not change the promised receipt date.');
  end;

  [Test]
  procedure GivenBlankProposedDeliveryDate_WhenChangeDateIsApplied_ThenHandlerRejectsWithoutChangingPurchaseLine()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    ApplySucceeded: Boolean;
    ErrorText: Text;
    OriginalPromisedDate: Date;
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine);
    OriginalPromisedDate := WorkDate() + 4;
    PurchaseLine.Validate("Promised Receipt Date", OriginalPromisedDate);
    PurchaseLine.Modify(false);
    ProposalLine.Validate("Proposed Delivery Date", 0D);
    ProposalLine.Modify(false);

    // When
    ApplySucceeded := this.TryApplyChangeDate(ProposalLine, PurchaseHeader);
    ErrorText := GetLastErrorText();

    // Then
    this.Assert.IsFalse(ApplySucceeded, 'A blank proposed delivery date must be rejected.');
    this.Assert.IsTrue(StrPos(ErrorText, 'VCH-VAL-0020') > 0, 'A blank proposed delivery date must return the delivery date validation code.');
    this.Assert.IsTrue(PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseLine."Line No."), 'The expected purchase line record must exist.');
    this.Assert.AreEqual(OriginalPromisedDate, PurchaseLine."Promised Receipt Date", 'A rejected blank date change must not change the promised receipt date.');
  end;

  [TryFunction]
  local procedure TryApplyChangeDate(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    ChangeDateHandler: Codeunit "AMC Change Date Handler";
  begin
    ChangeDateHandler.Apply(ProposalLine, PurchaseHeader);
  end;

  local procedure CreateSourceRecords(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; var ProposalLine: Record "AMC Vendor Proposal Line")
  var
    Vendor: Record Vendor;
    VendorProposal: Record "AMC Vendor Proposal";
    VendorRequest: Record "AMC Vendor Request";
    RequestLine: Record "AMC Vendor Request Line";
    ProposalNo: Code[20];
    PurchaseOrderNo: Code[20];
    RequestNo: Code[20];
    VendorNo: Code[20];
  begin
    ProposalNo := this.CreateIdentifier();
    PurchaseOrderNo := this.CreateIdentifier();
    RequestNo := this.CreateIdentifier();
    VendorNo := this.CreateIdentifier();

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
    PurchaseLine.Insert(false);
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
    ProposalLine.Init();
    ProposalLine.Validate("Proposal No.", ProposalNo);
    ProposalLine.Validate("Line No.", 10000);
    ProposalLine.Validate("Request Line No.", RequestLine."Line No.");
    ProposalLine.Validate("Line Type", ProposalLine."Line Type"::"Change Date");
    ProposalLine.Validate("Sequence No.", 1);
    ProposalLine.Insert(false);
  end;

  local procedure CreateIdentifier(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
