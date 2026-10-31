namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50136 "AMC Change Qty Handler Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";
    TestLibrary: Codeunit "AMC Test Library";

  [Test]
  procedure GivenValidReducedQuantity_WhenChangeQuantityIsApplied_ThenPurchaseLineQuantityIsChanged()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    RequestLine: Record "AMC Vendor Request Line";
    ChangeQtyHandler: Codeunit "AMC Change Qty Handler";
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine, RequestLine, 10);
    ProposalLine.Validate("Proposed Quantity", 5);
    ProposalLine.Modify(false);

    // When
    ChangeQtyHandler.Apply(ProposalLine, PurchaseHeader);

    // Then
    PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseLine."Line No.");
    this.Assert.AreEqual(5, PurchaseLine.Quantity, 'Applying a valid quantity change must update the purchase line quantity.');
  end;

  [Test]
  procedure GivenQuantityBelowReceivedAmounts_WhenChangeQuantityIsValidated_ThenBothMinimumQuantityErrorsAreReturned()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    RequestLine: Record "AMC Vendor Request Line";
    ValidationResult: Codeunit "AMC Validation Result";
    ChangeQtyHandler: Codeunit "AMC Change Qty Handler";
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine, RequestLine, 10);
    PurchaseLine.Validate("Quantity Received", 5);
    PurchaseLine.Validate("Qty. Rcd. Not Invoiced", 4);
    PurchaseLine.Modify(false);
    ProposalLine.Validate("Proposed Quantity", 3);
    ProposalLine.Modify(false);

    // When
    ChangeQtyHandler.Validate(ProposalLine, RequestLine, ValidationResult);

    // Then
    this.Assert.AreEqual(2, ValidationResult.GetErrorCount(), 'A quantity below received amounts must return both applicable validation errors.');
    this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0013') > 0, 'The received quantity validation error must be returned.');
    this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0014') > 0, 'The received not invoiced quantity validation error must be returned.');
  end;

  [Test]
  procedure GivenNonPositiveQuantity_WhenChangeQuantityIsValidated_ThenPositiveQuantityErrorIsReturned()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    RequestLine: Record "AMC Vendor Request Line";
    ValidationResult: Codeunit "AMC Validation Result";
    ChangeQtyHandler: Codeunit "AMC Change Qty Handler";
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine, RequestLine, 10);
    ProposalLine.Validate("Proposed Quantity", 0);
    ProposalLine.Modify(false);

    // When
    ChangeQtyHandler.Validate(ProposalLine, RequestLine, ValidationResult);

    // Then
    this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'A non-positive quantity must be rejected.');
    this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0010') > 0, 'The positive quantity validation error must be returned.');
  end;

  [Test]
  procedure GivenIncreaseIsForbidden_WhenChangeQuantityIsValidated_ThenIncreaseIsRejected()
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    RequestLine: Record "AMC Vendor Request Line";
    ValidationResult: Codeunit "AMC Validation Result";
    ChangeQtyHandler: Codeunit "AMC Change Qty Handler";
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine, RequestLine, 10);
    CollaborationSetup.GetSetup();
    CollaborationSetup.Validate("Allow Quantity Increase", false);
    CollaborationSetup.Modify(false);
    ProposalLine.Validate("Proposed Quantity", 11);
    ProposalLine.Modify(false);

    // When
    ChangeQtyHandler.Validate(ProposalLine, RequestLine, ValidationResult);

    // Then
    this.Assert.AreEqual(1, ValidationResult.GetErrorCount(), 'An increase must be rejected when quantity increases are not allowed.');
    this.Assert.IsTrue(StrPos(ValidationResult.AsErrorText(), 'VCH-VAL-0015') > 0, 'The quantity increase validation error must be returned.');
  end;

  [Test]
  procedure GivenQuantityEqualsReceivedFloor_WhenValidated_ThenNeitherMinimumErrorIsReturned()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    RequestLine: Record "AMC Vendor Request Line";
    ValidationResult: Codeunit "AMC Validation Result";
    ChangeQtyHandler: Codeunit "AMC Change Qty Handler";
  begin
    // Given
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine, RequestLine, 10);
    PurchaseLine.Validate("Quantity Received", 5);
    PurchaseLine.Validate("Qty. Rcd. Not Invoiced", 4);
    PurchaseLine.Modify(false);
    ProposalLine.Validate("Proposed Quantity", 5);
    // When
    ChangeQtyHandler.Validate(ProposalLine, RequestLine, ValidationResult);
    // Then
    this.Assert.AreEqual(0, ValidationResult.GetErrorCount(), 'Equality with the received floor must not return either minimum-quantity error.');
  end;

  local procedure CreateSourceRecords(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; Quantity: Decimal)
  var
    Vendor: Record Vendor;
    VendorProposal: Record "AMC Vendor Proposal";
    VendorRequest: Record "AMC Vendor Request";
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
    PurchaseLine.Validate(Quantity, Quantity);
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
    ProposalLine.Validate("Line Type", ProposalLine."Line Type"::"Change Quantity");
    ProposalLine.Validate("Sequence No.", 1);
    ProposalLine.Insert(false);
  end;

  local procedure CreateIdentifier(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
