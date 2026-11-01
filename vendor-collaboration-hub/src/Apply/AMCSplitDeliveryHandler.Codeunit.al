namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Applies split deliveries by updating the origin line and inserting subsequent split lines.
/// </summary>
codeunit 50114 "AMC Split Delivery Handler" implements "AMC IProposalLineHandler"
{
  Permissions = tabledata "AMC Vendor Proposal" = r,
                tabledata "AMC Vendor Proposal Line" = r,
                tabledata "AMC Vendor Request Line" = r,
                tabledata "Purchase Line" = rm;

  /// <summary>
  /// Adds no handler-specific checks; shared proposal validation checks split counts, quantities and dates.
  /// </summary>
  /// <param name="ProposalLine">The split proposal line; unchanged.</param>
  /// <param name="RequestLine">The request-line snapshot; unchanged.</param>
  /// <param name="Result">The validation result; no errors are appended by this handler.</param>
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
  end;

  /// <summary>
  /// Updates the origin for the first split or builds a new line after the preceding applied split, stamping proposal origin.
  /// </summary>
  /// <param name="ProposalLine">Supplies the split quantity, date and sequence; callers apply splits in sequence order.</param>
  /// <param name="PurchaseHeader">Identifies the target order under the caller's application context.</param>
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

    if not OriginPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.") then
      Error(this.RequiredRecordNotFoundErr, OriginPurchaseLine.TableCaption());
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
    VendorProposal.SetLoadFields("Request No.");
    if not VendorProposal.Get(ProposalLine."Proposal No.") then
      Error(this.RequiredRecordNotFoundErr, VendorProposal.TableCaption());
    if not RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.") then
      Error(this.RequiredRecordNotFoundErr, RequestLine.TableCaption());
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
    PreviousProposalLine.SetLoadFields("Line No.");
    if not PreviousProposalLine.FindLast() then
      exit(false);

    PreviousPurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
    PreviousPurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
    PreviousPurchaseLine.SetRange("AMC Origin Proposal No.", ProposalLine."Proposal No.");
    PreviousPurchaseLine.SetRange("AMC Origin Proposal Line No.", PreviousProposalLine."Line No.");
    exit(PreviousPurchaseLine.FindFirst());
  end;

  var
    RequiredRecordNotFoundErr: Label 'VCH-DAT-0001: The %1 record required to process the proposal could not be found.', Comment = '%1 = table caption';
}
