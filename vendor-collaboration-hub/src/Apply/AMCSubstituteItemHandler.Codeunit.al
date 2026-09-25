namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50115 "AMC Substitute Item Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
    Result.AddError(this.SubstituteItemNotAvailableCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", this.SubstituteItemNotAvailableErr);
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  begin
    Error(this.SubstituteItemNotAvailableApplyErr);
  end;

  var
    SubstituteItemNotAvailableCodeLbl: Label 'VCH-VAL-0051', Locked = true;
    SubstituteItemNotAvailableErr: Label 'Substitute item proposal lines are not available yet.';
    SubstituteItemNotAvailableApplyErr: Label 'VCH-APL-0008: Substitute item application is not available yet.';
}
