namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50112 "AMC Change Qty Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    PurchaseLine: Record "Purchase Line";
  begin
    this.GetPurchaseLine(ProposalLine, RequestLine, PurchaseLine);
    if ProposalLine."Proposed Quantity" <= 0 then
      this.AddValidationError(Result, ProposalLine, this.QuantityMustBePositiveCodeLbl, this.QuantityMustBePositiveErr);

    if ProposalLine."Proposed Quantity" < PurchaseLine."Quantity Received" then
      this.AddValidationError(Result, ProposalLine, this.QuantityBelowReceivedCodeLbl,
        StrSubstNo(this.QuantityBelowReceivedErr, ProposalLine."Proposed Quantity", PurchaseLine."Quantity Received"));

    if ProposalLine."Proposed Quantity" < PurchaseLine."Qty. Rcd. Not Invoiced" then
      this.AddValidationError(Result, ProposalLine, this.QuantityBelowReceivedNotInvoicedCodeLbl,
        StrSubstNo(this.QuantityBelowReceivedNotInvoicedErr, ProposalLine."Proposed Quantity", PurchaseLine."Qty. Rcd. Not Invoiced"));

    if CollaborationSetup.Get() and
       (ProposalLine."Proposed Quantity" > PurchaseLine.Quantity) and
       not CollaborationSetup."Allow Quantity Increase" then
      this.AddValidationError(Result, ProposalLine, this.QuantityIncreaseNotAllowedCodeLbl, this.QuantityIncreaseNotAllowedErr);
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
    PurchaseLine.Validate(Quantity, ProposalLine."Proposed Quantity");
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

  local procedure AddValidationError(var Result: Codeunit "AMC Validation Result"; ProposalLine: Record "AMC Vendor Proposal Line"; ErrorCode: Code[20]; ErrorText: Text)
  begin
    Result.AddError(ErrorCode, ProposalLine."Request Line No.", ProposalLine."Sequence No.", ErrorText);
  end;

  var
    QuantityMustBePositiveCodeLbl: Label 'VCH-VAL-0010', Locked = true;
    QuantityBelowReceivedCodeLbl: Label 'VCH-VAL-0013', Locked = true;
    QuantityBelowReceivedNotInvoicedCodeLbl: Label 'VCH-VAL-0014', Locked = true;
    QuantityIncreaseNotAllowedCodeLbl: Label 'VCH-VAL-0015', Locked = true;
    QuantityMustBePositiveErr: Label 'Proposed quantity must be positive.';
    QuantityBelowReceivedErr: Label 'Proposed quantity %1 cannot be below received quantity %2.', Comment = '%1 = proposed quantity, %2 = received quantity';
    QuantityBelowReceivedNotInvoicedErr: Label 'Proposed quantity %1 cannot be below received not invoiced quantity %2.', Comment = '%1 = proposed quantity, %2 = received not invoiced quantity';
    QuantityIncreaseNotAllowedErr: Label 'Increasing the purchase line quantity is not allowed by vendor collaboration setup.';
}
