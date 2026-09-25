namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50114 "AMC Split Delivery Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    NewPurchaseLine: Record "Purchase Line";
    OriginPurchaseLine: Record "Purchase Line";
    RequestLine: Record "AMC Vendor Request Line";
    PurchaseLineBuilder: Codeunit "AMC Purchase Line Builder";
  begin
    this.GetRequestLine(ProposalLine, RequestLine);
    if this.GetPreviousSplitPurchaseLine(ProposalLine, PurchaseHeader, OriginPurchaseLine) then begin
      PurchaseLineBuilder.Build(OriginPurchaseLine, ProposalLine, OriginPurchaseLine."No.", OriginPurchaseLine."Variant Code", ProposalLine."Proposed Quantity", ProposalLine."Proposed Delivery Date", NewPurchaseLine);
      exit;
    end;

    OriginPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.");
    OriginPurchaseLine.Validate(Quantity, ProposalLine."Proposed Quantity");
    OriginPurchaseLine.Validate("Promised Receipt Date", ProposalLine."Proposed Delivery Date");
    OriginPurchaseLine.Validate("AMC Origin Proposal No.", ProposalLine."Proposal No.");
    OriginPurchaseLine.Validate("AMC Origin Proposal Line No.", ProposalLine."Line No.");
    OriginPurchaseLine.Modify(true);
  end;

  local procedure GetRequestLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.Get(ProposalLine."Proposal No.");
    RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.");
  end;

  local procedure GetPreviousSplitPurchaseLine(ProposalLine: Record "AMC Vendor Proposal Line"; PurchaseHeader: Record "Purchase Header"; var PreviousPurchaseLine: Record "Purchase Line"): Boolean
  var
    PreviousProposalLine: Record "AMC Vendor Proposal Line";
  begin
    PreviousProposalLine.SetCurrentKey("Proposal No.", "Request Line No.", "Sequence No.");
    PreviousProposalLine.SetRange("Proposal No.", ProposalLine."Proposal No.");
    PreviousProposalLine.SetRange("Request Line No.", ProposalLine."Request Line No.");
    PreviousProposalLine.SetRange("Line Type", ProposalLine."Line Type"::"Split Delivery");
    PreviousProposalLine.SetFilter("Sequence No.", '<%1', ProposalLine."Sequence No.");
    if not PreviousProposalLine.FindLast() then
      exit(false);

    PreviousPurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
    PreviousPurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
    PreviousPurchaseLine.SetRange("AMC Origin Proposal No.", ProposalLine."Proposal No.");
    PreviousPurchaseLine.SetRange("AMC Origin Proposal Line No.", PreviousProposalLine."Line No.");
    exit(PreviousPurchaseLine.FindFirst());
  end;
}
