namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Validates proposed quantities against receipts and setup and applies purchase-line quantity changes.
/// </summary>
codeunit 50112 "AMC Change Qty Handler" implements "AMC IProposalLineHandler"
{
  Permissions = tabledata "AMC Collaboration Setup" = r,
                tabledata "AMC Vendor Proposal" = r,
                tabledata "AMC Vendor Request Line" = r,
                tabledata "Purchase Line" = rm;

  /// <summary>
  /// Checks positive quantity, receipt-related minimums and the setup policy for quantity increases.
  /// </summary>
  /// <param name="ProposalLine">Supplies the proposed quantity and proposal identity.</param>
  /// <param name="RequestLine">Identifies the snapshotted purchase line.</param>
  /// <param name="Result">Receives quantity errors; missing required purchasing records raise an error.</param>
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

  /// <summary>
  /// Rechecks quantity rules and validates and persists the proposed purchase-line quantity.
  /// </summary>
  /// <param name="ProposalLine">Supplies the proposed quantity and request-line identity.</param>
  /// <param name="PurchaseHeader">Identifies the target order under the caller's application context.</param>
  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    PurchaseLine: Record "Purchase Line";
    RequestLine: Record "AMC Vendor Request Line";
    Result: Codeunit "AMC Validation Result";
  begin
    this.GetRequestLine(ProposalLine, RequestLine);
    this.Validate(ProposalLine, RequestLine, Result);
    if Result.HasErrors() then
      Error(ErrorInfo.Create(Result.AsErrorText(), false));

    if not PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.") then
      Error(this.RequiredRecordNotFoundErr, PurchaseLine.TableCaption());
    PurchaseLine.Validate(Quantity, ProposalLine."Proposed Quantity");
    PurchaseLine.Modify(true);
  end;

  local procedure GetPurchaseLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var PurchaseLine: Record "Purchase Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.SetLoadFields("Purchase Order No.");
    if not VendorProposal.Get(ProposalLine."Proposal No.") then
      Error(this.RequiredRecordNotFoundErr, VendorProposal.TableCaption());
    if not PurchaseLine.Get(PurchaseLine."Document Type"::Order, VendorProposal."Purchase Order No.", RequestLine."Purchase Line No.") then
      Error(this.RequiredRecordNotFoundErr, PurchaseLine.TableCaption());
  end;

  local procedure GetRequestLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.SetLoadFields("Request No.");
    if not VendorProposal.Get(ProposalLine."Proposal No.") then
      Error(this.RequiredRecordNotFoundErr, VendorProposal.TableCaption());
    if not RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.") then
      Error(this.RequiredRecordNotFoundErr, RequestLine.TableCaption());
  end;

  local procedure AddValidationError(var Result: Codeunit "AMC Validation Result"; ProposalLine: Record "AMC Vendor Proposal Line"; ErrorCode: Code[20]; ErrorText: Text)
  begin
    Result.AddError(ErrorCode, ProposalLine."Request Line No.", ProposalLine."Sequence No.", ErrorText);
  end;

  var
    RequiredRecordNotFoundErr: Label 'VCH-DAT-0001: The %1 record required to process the proposal could not be found.', Comment = '%1 = table caption';
    QuantityMustBePositiveCodeLbl: Label 'VCH-VAL-0010', Locked = true;
    QuantityBelowReceivedCodeLbl: Label 'VCH-VAL-0013', Locked = true;
    QuantityBelowReceivedNotInvoicedCodeLbl: Label 'VCH-VAL-0014', Locked = true;
    QuantityIncreaseNotAllowedCodeLbl: Label 'VCH-VAL-0015', Locked = true;
    QuantityMustBePositiveErr: Label 'Proposed quantity must be positive.';
    QuantityBelowReceivedErr: Label 'Proposed quantity %1 cannot be below received quantity %2.', Comment = '%1 = proposed quantity, %2 = received quantity';
    QuantityBelowReceivedNotInvoicedErr: Label 'Proposed quantity %1 cannot be below received not invoiced quantity %2.', Comment = '%1 = proposed quantity, %2 = received not invoiced quantity';
    QuantityIncreaseNotAllowedErr: Label 'Increasing the purchase line quantity is not allowed by vendor collaboration setup.';
}
