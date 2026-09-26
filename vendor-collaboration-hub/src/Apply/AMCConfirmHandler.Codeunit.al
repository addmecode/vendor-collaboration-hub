namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50111 "AMC Confirm Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    PurchaseLine: Record "Purchase Line";
    RequestLine: Record "AMC Vendor Request Line";
  begin
    this.GetRequestLine(ProposalLine, RequestLine);
    PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.");
    PurchaseLine.Validate("Promised Receipt Date", RequestLine."Requested Delivery Date");
    PurchaseLine.Validate("AMC Vendor Confirmed", true);
    PurchaseLine.Modify(true);
  end;

  local procedure GetRequestLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.Get(ProposalLine."Proposal No.");
    RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.");
  end;
}
