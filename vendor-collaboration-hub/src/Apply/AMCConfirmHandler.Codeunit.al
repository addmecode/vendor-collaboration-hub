namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Confirms a purchase line using the requested delivery date from its snapshot.
/// </summary>
codeunit 50111 "AMC Confirm Handler" implements "AMC IProposalLineHandler"
{
  Permissions = tabledata "AMC Vendor Proposal" = r,
                tabledata "AMC Vendor Request Line" = r,
                tabledata "Purchase Line" = rm;

  /// <summary>
  /// Adds no confirmation-specific checks; shared proposal validation is performed by the caller.
  /// </summary>
  /// <param name="ProposalLine">The confirmation proposal line; unchanged.</param>
  /// <param name="RequestLine">The request-line snapshot; unchanged.</param>
  /// <param name="Result">The validation result; no errors are appended by this handler.</param>
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
  end;

  /// <summary>
  /// Sets the purchase line's promised receipt date to the snapshot's requested date and marks it vendor-confirmed.
  /// </summary>
  /// <param name="ProposalLine">Identifies the proposal and request line to confirm.</param>
  /// <param name="PurchaseHeader">Identifies the target order under the caller's application context.</param>
  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    PurchaseLine: Record "Purchase Line";
    RequestLine: Record "AMC Vendor Request Line";
  begin
    this.GetRequestLine(ProposalLine, RequestLine);
    if not PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.") then
      Error(this.RequiredRecordNotFoundErr, PurchaseLine.TableCaption());
    PurchaseLine.Validate("Promised Receipt Date", RequestLine."Requested Delivery Date");
    PurchaseLine.Validate("AMC Vendor Confirmed", true);
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
}
