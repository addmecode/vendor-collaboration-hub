namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50113 "AMC Change Date Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
    if ProposalLine."Proposed Delivery Date" < WorkDate() then
      Result.AddError(this.DeliveryDateInPastCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", this.DeliveryDateInPastErr);
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    PurchaseLine: Record "Purchase Line";
    RequestLine: Record "AMC Vendor Request Line";
    Result: Codeunit "AMC Validation Result";
  begin
    this.GetRequestLine(ProposalLine, RequestLine);
    this.Validate(ProposalLine, RequestLine, Result);
    if Result.HasErrors() then
      Error(Result.AsErrorText());

    PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.");
    PurchaseLine.Validate("Promised Receipt Date", ProposalLine."Proposed Delivery Date");
    PurchaseLine.Modify(true);
  end;

  local procedure GetRequestLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.Get(ProposalLine."Proposal No.");
    RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.");
  end;

  var
    DeliveryDateInPastCodeLbl: Label 'VCH-VAL-0020', Locked = true;
    DeliveryDateInPastErr: Label 'Proposed delivery date cannot be before the work date.';
}
