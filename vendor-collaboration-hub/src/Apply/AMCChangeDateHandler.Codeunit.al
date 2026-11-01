namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Validates and applies proposed purchase-line promised receipt dates.
/// </summary>
codeunit 50113 "AMC Change Date Handler" implements "AMC IProposalLineHandler"
{
  Permissions = tabledata "AMC Vendor Proposal" = r,
                tabledata "AMC Vendor Request Line" = r,
                tabledata "Purchase Line" = rm;

  /// <summary>
  /// Appends an error when the proposed delivery date precedes the work date.
  /// </summary>
  /// <param name="ProposalLine">Supplies the proposed date and error coordinates.</param>
  /// <param name="RequestLine">The request-line snapshot, unused by this check.</param>
  /// <param name="Result">Receives any date validation error without clearing earlier errors.</param>
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
    if ProposalLine."Proposed Delivery Date" < WorkDate() then
      Result.AddError(this.DeliveryDateInPastCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", this.DeliveryDateInPastErr);
  end;

  /// <summary>
  /// Rechecks the proposed date and updates the corresponding purchase line's promised receipt date.
  /// </summary>
  /// <param name="ProposalLine">Supplies the proposed date and request-line identity.</param>
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
    PurchaseLine.Validate("Promised Receipt Date", ProposalLine."Proposed Delivery Date");
    PurchaseLine.Modify(true);
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

  var
    RequiredRecordNotFoundErr: Label 'VCH-DAT-0001: The %1 record required to process the proposal could not be found.', Comment = '%1 = table caption';
    DeliveryDateInPastCodeLbl: Label 'VCH-VAL-0020', Locked = true;
    DeliveryDateInPastErr: Label 'Proposed delivery date cannot be before the work date.';
}
