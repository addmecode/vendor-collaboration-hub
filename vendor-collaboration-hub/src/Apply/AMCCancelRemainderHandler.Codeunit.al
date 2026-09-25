namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50116 "AMC Cancel Remainder Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
    Result.AddError(this.CancelRemainderNotAvailableCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", this.CancelRemainderNotAvailableErr);
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  begin
    Error(this.CancelRemainderNotAvailableApplyErr);
  end;

  var
    CancelRemainderNotAvailableCodeLbl: Label 'VCH-VAL-0052', Locked = true;
    CancelRemainderNotAvailableErr: Label 'Cancel remainder proposal lines are not available yet.';
    CancelRemainderNotAvailableApplyErr: Label 'VCH-APL-0009: Cancel remainder application is not available yet.';
}
