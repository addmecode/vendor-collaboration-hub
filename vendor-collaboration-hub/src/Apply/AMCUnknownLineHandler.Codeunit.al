namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Rejects unsupported proposal-line types during validation and application.
/// </summary>
codeunit 50125 "AMC Unknown Line Handler" implements "AMC IProposalLineHandler"
{
  /// <summary>
  /// Appends an unsupported-line-type validation error without changing purchasing data.
  /// </summary>
  /// <param name="ProposalLine">Supplies the unsupported type ordinal and error coordinates.</param>
  /// <param name="RequestLine">The request-line snapshot, unused by this handler.</param>
  /// <param name="Result">Receives the unsupported-type error.</param>
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
    Result.AddError(this.UnsupportedLineTypeCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.",
      StrSubstNo(this.UnsupportedLineTypeErr, ProposalLine."Line No.", ProposalLine."Request Line No.", ProposalLine."Sequence No.", ProposalLine."Line Type".AsInteger()));
  end;

  /// <summary>
  /// Always raises the controlled unsupported-line-type application error without changing purchasing data.
  /// </summary>
  /// <param name="ProposalLine">Supplies the unsupported type ordinal and error coordinates.</param>
  /// <param name="PurchaseHeader">The target order, unused and unchanged.</param>
  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  begin
    Error(this.UnsupportedLineTypeApplyErr, ProposalLine."Line No.", ProposalLine."Request Line No.", ProposalLine."Sequence No.", ProposalLine."Line Type".AsInteger());
  end;

  var
    UnsupportedLineTypeCodeLbl: Label 'VCH-VAL-0003', Locked = true;
    UnsupportedLineTypeErr: Label 'Proposal line %1 for request line %2, sequence %3 has unsupported line type ordinal %4.', Comment = '%1 = proposal line number, %2 = request line number, %3 = sequence number, %4 = proposal line type ordinal';
    UnsupportedLineTypeApplyErr: Label 'VCH-APL-0006: Proposal line %1 for request line %2, sequence %3 has unsupported line type ordinal %4.', Comment = '%1 = proposal line number, %2 = request line number, %3 = sequence number, %4 = proposal line type ordinal';
}
