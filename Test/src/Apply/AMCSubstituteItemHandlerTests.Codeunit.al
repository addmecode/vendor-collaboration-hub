namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50139 "AMC Substitute Item Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";

  [Test]
  procedure GivenRegisteredSubstitute_WhenSubstituteItemIsApplied_ThenSubstituteIsInsertedAndOriginIsCancelled()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    SubstitutePurchaseLine: Record "Purchase Line";
    SubstituteItemHandler: Codeunit "AMC Substitute Item Handler";
    DeliveryDate: Date;
  begin
    // Given
    DeliveryDate := WorkDate() + 7;
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine);
    ProposalLine."Proposed Item No." := 'ITEM-B2';
    ProposalLine."Proposed Quantity" := 500;
    ProposalLine."Proposed Delivery Date" := DeliveryDate;
    ProposalLine.Modify(false);

    // When
    SubstituteItemHandler.Apply(ProposalLine, PurchaseHeader);

    // Then
    PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 10000);
    SubstitutePurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", 15000);
    this.Assert.AreEqual(0, PurchaseLine.Quantity, 'The original purchase line must be cancelled.');
    this.Assert.AreEqual(ProposalLine."Proposal No.", PurchaseLine."AMC Origin Proposal No.", 'The cancelled origin line must be stamped with the proposal.');
    this.Assert.AreEqual('ITEM-B2', SubstitutePurchaseLine."No.", 'The inserted purchase line must use the registered substitute item.');
    this.Assert.AreEqual(500, SubstitutePurchaseLine.Quantity, 'The inserted substitute line must use the proposed quantity.');
    this.Assert.AreEqual(DeliveryDate, SubstitutePurchaseLine."Promised Receipt Date", 'The inserted substitute line must use the proposed delivery date.');
    this.Assert.AreEqual(ProposalLine."Line No.", SubstitutePurchaseLine."AMC Origin Proposal Line No.", 'The substitute line must be stamped with the proposal line.');
  end;

  local procedure CreateSourceRecords(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; var ProposalLine: Record "AMC Vendor Proposal Line")
  var
    ItemSubstitution: Record "Item Substitution";
    NextPurchaseLine: Record "Purchase Line";
    GenProductPostingGroup: Record "Gen. Product Posting Group";
    InventoryPostingGroup: Record "Inventory Posting Group";
    VATProductPostingGroup: Record "VAT Product Posting Group";
    Vendor: Record Vendor;
    VendorPostingGroup: Record "Vendor Posting Group";
    VendorProposal: Record "AMC Vendor Proposal";
    VendorRequest: Record "AMC Vendor Request";
    RequestLine: Record "AMC Vendor Request Line";
    ProposalNo: Code[20];
    PurchaseOrderNo: Code[20];
    RequestNo: Code[20];
    VendorNo: Code[20];
    GenProductPostingGroupCode: Code[20];
    InventoryPostingGroupCode: Code[20];
    VATProductPostingGroupCode: Code[20];
    VendorPostingGroupCode: Code[20];
  begin
    ProposalNo := this.CreateIdentifier();
    PurchaseOrderNo := this.CreateIdentifier();
    RequestNo := this.CreateIdentifier();
    VendorNo := this.CreateIdentifier();
    GenProductPostingGroupCode := this.CreateIdentifier();
    InventoryPostingGroupCode := this.CreateIdentifier();
    VATProductPostingGroupCode := this.CreateIdentifier();
    VendorPostingGroupCode := this.CreateIdentifier();
    GenProductPostingGroup.Init();
    GenProductPostingGroup.Code := GenProductPostingGroupCode;
    GenProductPostingGroup.Description := GenProductPostingGroupCode;
    GenProductPostingGroup.Insert(false);
    InventoryPostingGroup.Init();
    InventoryPostingGroup.Code := InventoryPostingGroupCode;
    InventoryPostingGroup.Description := InventoryPostingGroupCode;
    InventoryPostingGroup.Insert(false);
    VATProductPostingGroup.Init();
    VATProductPostingGroup.Code := VATProductPostingGroupCode;
    VATProductPostingGroup.Description := VATProductPostingGroupCode;
    VATProductPostingGroup.Insert(false);
    VendorPostingGroup.Init();
    VendorPostingGroup.Code := VendorPostingGroupCode;
    VendorPostingGroup.Description := VendorPostingGroupCode;
    VendorPostingGroup.Insert(false);
    this.CreateItem('ITEM-B', GenProductPostingGroupCode, InventoryPostingGroupCode, VATProductPostingGroupCode);
    this.CreateItem('ITEM-B2', GenProductPostingGroupCode, InventoryPostingGroupCode, VATProductPostingGroupCode);
    ItemSubstitution.Init();
    ItemSubstitution."No." := 'ITEM-B';
    ItemSubstitution."Substitute No." := 'ITEM-B2';
    ItemSubstitution.Insert(false);
    Vendor.Init();
    Vendor."No." := VendorNo;
    Vendor.Name := VendorNo;
    Vendor.Validate("Vendor Posting Group", VendorPostingGroupCode);
    Vendor.Insert(false);
    PurchaseHeader.Init();
    PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
    PurchaseHeader."No." := PurchaseOrderNo;
    PurchaseHeader.Validate("Buy-from Vendor No.", VendorNo);
    PurchaseHeader.Insert(false);
    PurchaseLine.Init();
    PurchaseLine."Document Type" := PurchaseHeader."Document Type";
    PurchaseLine."Document No." := PurchaseHeader."No.";
    PurchaseLine."Line No." := 10000;
    PurchaseLine.Validate("Buy-from Vendor No.", VendorNo);
    PurchaseLine.Validate("Pay-to Vendor No.", VendorNo);
    PurchaseLine.Type := PurchaseLine.Type::Item;
    PurchaseLine."No." := 'ITEM-B';
    PurchaseLine.Quantity := 500;
    PurchaseLine.Insert(false);
    NextPurchaseLine.Init();
    NextPurchaseLine."Document Type" := PurchaseHeader."Document Type";
    NextPurchaseLine."Document No." := PurchaseHeader."No.";
    NextPurchaseLine."Line No." := 20000;
    NextPurchaseLine.Insert(false);
    VendorRequest.Init();
    VendorRequest."No." := RequestNo;
    VendorRequest."Vendor No." := VendorNo;
    VendorRequest."Purchase Order No." := PurchaseOrderNo;
    VendorRequest.Insert(false);
    RequestLine.Init();
    RequestLine."Request No." := RequestNo;
    RequestLine."Line No." := 10000;
    RequestLine."Purchase Line No." := PurchaseLine."Line No.";
    RequestLine.Insert(false);
    VendorProposal.Init();
    VendorProposal."No." := ProposalNo;
    VendorProposal."Request No." := RequestNo;
    VendorProposal."Vendor No." := VendorNo;
    VendorProposal."Purchase Order No." := PurchaseOrderNo;
    VendorProposal."Idempotency Key" := ProposalNo;
    VendorProposal.Insert(false);
    ProposalLine.Init();
    ProposalLine."Proposal No." := ProposalNo;
    ProposalLine."Line No." := 10000;
    ProposalLine."Request Line No." := 10000;
    ProposalLine."Line Type" := ProposalLine."Line Type"::"Substitute Item";
    ProposalLine."Sequence No." := 1;
    ProposalLine.Insert(false);
  end;

  local procedure CreateItem(ItemNo: Code[20]; GenProductPostingGroupCode: Code[20]; InventoryPostingGroupCode: Code[20]; VATProductPostingGroupCode: Code[20])
  var
    Item: Record Item;
  begin
    Item.Init();
    Item."No." := ItemNo;
    Item.Description := ItemNo;
    Item.Validate("Gen. Prod. Posting Group", GenProductPostingGroupCode);
    Item.Validate("Inventory Posting Group", InventoryPostingGroupCode);
    Item.Validate("VAT Prod. Posting Group", VATProductPostingGroupCode);
    Item.Insert(false);
  end;

  local procedure CreateIdentifier(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
