namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50115 "AMC Substitute Item Handler" implements "AMC IProposalLineHandler"
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
    OriginPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.");
    PurchaseLineBuilder.Build(OriginPurchaseLine, ProposalLine, ProposalLine."Proposed Item No.", ProposalLine."Proposed Variant Code", ProposalLine."Proposed Quantity", ProposalLine."Proposed Delivery Date", NewPurchaseLine);

    OriginPurchaseLine.Validate(Quantity, OriginPurchaseLine.Quantity - ProposalLine."Proposed Quantity");
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
}
