namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50116 "AMC Cancel Remainder Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  var
    PurchaseLine: Record "Purchase Line";
  begin
    this.GetPurchaseLine(ProposalLine, RequestLine, PurchaseLine);
    if PurchaseLine."Quantity Received" >= PurchaseLine.Quantity then
      Result.AddError(this.NoRemainderToCancelCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", this.NoRemainderToCancelErr);
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
    PurchaseLine.Validate(Quantity, PurchaseLine."Quantity Received");
    PurchaseLine.Validate("AMC Origin Proposal No.", ProposalLine."Proposal No.");
    PurchaseLine.Validate("AMC Origin Proposal Line No.", ProposalLine."Line No.");
    PurchaseLine.Modify(true);
  end;

  local procedure GetPurchaseLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var PurchaseLine: Record "Purchase Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.Get(ProposalLine."Proposal No.");
    PurchaseLine.Get(PurchaseLine."Document Type"::Order, VendorProposal."Purchase Order No.", RequestLine."Purchase Line No.");
  end;

  local procedure GetRequestLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.Get(ProposalLine."Proposal No.");
    RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.");
  end;

  var
    NoRemainderToCancelCodeLbl: Label 'VCH-VAL-0013', Locked = true;
    NoRemainderToCancelErr: Label 'The purchase line has no remaining quantity to cancel.';
}
