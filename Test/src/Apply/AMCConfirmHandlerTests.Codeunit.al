namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50135 "AMC Confirm Handler Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";

  [Test]
  procedure GivenRequestDate_WhenConfirmIsApplied_ThenPurchaseLineIsConfirmedWithRequestDate()
  var
    PurchaseHeader: Record "Purchase Header";
    PurchaseLine: Record "Purchase Line";
    ProposalLine: Record "AMC Vendor Proposal Line";
    ConfirmHandler: Codeunit "AMC Confirm Handler";
    RequestDate: Date;
  begin
    // Given
    RequestDate := WorkDate() + 5;
    this.CreateSourceRecords(PurchaseHeader, PurchaseLine, ProposalLine, RequestDate);

    // When
    ConfirmHandler.Apply(ProposalLine, PurchaseHeader);

    // Then
    PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", PurchaseLine."Line No.");
    this.Assert.AreEqual(RequestDate, PurchaseLine."Promised Receipt Date", 'Confirming must set the promised receipt date to the request date.');
    this.Assert.IsTrue(PurchaseLine."AMC Vendor Confirmed", 'Confirming must mark the purchase line as vendor confirmed.');
  end;

  local procedure CreateSourceRecords(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; var ProposalLine: Record "AMC Vendor Proposal Line"; RequestDate: Date)
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

    Vendor.Init();
    Vendor."No." := VendorNo;
    Vendor.Name := VendorNo;
    Vendor.Insert(false);

    PurchaseHeader.Init();
    PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
    PurchaseHeader."No." := PurchaseOrderNo;
    PurchaseHeader."Buy-from Vendor No." := VendorNo;
    PurchaseHeader.Insert(false);

    PurchaseLine.Init();
    PurchaseLine."Document Type" := PurchaseHeader."Document Type";
    PurchaseLine."Document No." := PurchaseHeader."No.";
    PurchaseLine."Line No." := 10000;
    PurchaseLine."Requested Receipt Date" := RequestDate;
    PurchaseLine.Insert(false);

    VendorRequest.Init();
    VendorRequest."No." := RequestNo;
    VendorRequest."Vendor No." := VendorNo;
    VendorRequest."Purchase Order No." := PurchaseOrderNo;
    VendorRequest.Insert(false);

    RequestLine.Init();
    RequestLine."Request No." := RequestNo;
    RequestLine."Line No." := 10000;
    RequestLine."Purchase Line No." := PurchaseLine."Line No.";
    RequestLine."Requested Delivery Date" := RequestDate;
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
    ProposalLine."Request Line No." := RequestLine."Line No.";
    ProposalLine."Line Type" := ProposalLine."Line Type"::Confirm;
    ProposalLine."Sequence No." := 1;
    ProposalLine.Insert(false);
  end;

  local procedure CreateIdentifier(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;
}
