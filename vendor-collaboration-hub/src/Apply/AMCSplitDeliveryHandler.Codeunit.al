namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50114 "AMC Split Delivery Handler" implements "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
    Result.AddError(this.SplitDeliveryNotAvailableCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", this.SplitDeliveryNotAvailableErr);
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  begin
    Error(this.SplitDeliveryNotAvailableApplyErr);
  end;

  var
    SplitDeliveryNotAvailableCodeLbl: Label 'VCH-VAL-0050', Locked = true;
    SplitDeliveryNotAvailableErr: Label 'Split delivery proposal lines are not available yet.';
    SplitDeliveryNotAvailableApplyErr: Label 'VCH-APL-0007: Split delivery application is not available yet.';
}
