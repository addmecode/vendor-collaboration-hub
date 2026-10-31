namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50140 "AMC Cancel Remainder Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";
    TestLibrary: Codeunit "AMC Test Library";

  [Test]
  procedure GivenPartiallyReceivedLine_WhenCancelRemainderIsApplied_ThenQuantityEqualsReceivedQuantity()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    CancelRemainderHandler: Codeunit "AMC Cancel Remainder Handler";
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine);
    PurchaseLine.Validate("Quantity Received", 400);
    PurchaseLine.Modify(false);

    // When
    CancelRemainderHandler.Apply(ProposalLine, PurchaseHeader);

    // Then
    PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000);
    this.Assert.AreEqual(400, PurchaseLine.Quantity, 'Cancelling the remainder must retain the received quantity.');
    this.Assert.AreEqual(ProposalLine."Proposal No.", PurchaseLine."AMC Origin Proposal No.", 'The cancelled line must be stamped with the proposal.');
    this.Assert.AreEqual(ProposalLine."Line No.", PurchaseLine."AMC Origin Proposal Line No.", 'The cancelled line must be stamped with the proposal line.');
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
    PurchaseLine.Validate(Quantity, 1000);
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
    ProposalLine.Validate("Request Line No.", 10000);
    ProposalLine.Validate("Line Type", ProposalLine."Line Type"::"Cancel Remainder");
    ProposalLine.Validate("Sequence No.", 1);
    ProposalLine.Insert(false);
  end;

  local procedure CreateIdentifier(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
