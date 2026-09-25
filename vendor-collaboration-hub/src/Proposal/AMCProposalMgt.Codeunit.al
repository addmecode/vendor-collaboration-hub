namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;

codeunit 50101 "AMC Proposal Mgt"
{
    procedure CreateDraftFromRequest(VendorRequest: Record "AMC Vendor Request"): Code[20]
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        VendorProposal: Record "AMC Vendor Proposal";
        NoSeries: Codeunit "No. Series";
        ProposalNo: Code[20];
        ManualIdempotencyKeyLbl: Label 'MANUAL-%1', Locked = true;
    begin
        VendorRequest.Get(VendorRequest."No.");
        CollaborationSetup.GetSetup();

        ProposalNo := NoSeries.GetNextNo(CollaborationSetup."Proposal Nos.");
        VendorProposal.Init();
        VendorProposal."No." := ProposalNo;
        VendorProposal."Request No." := VendorRequest."No.";
        VendorProposal."Vendor No." := VendorRequest."Vendor No.";
        VendorProposal."Purchase Order No." := VendorRequest."Purchase Order No.";
        VendorProposal."Idempotency Key" := CopyStr(StrSubstNo(ManualIdempotencyKeyLbl, ProposalNo), 1, MaxStrLen(VendorProposal."Idempotency Key"));
        VendorProposal.Status := VendorProposal.Status::Draft;
        VendorProposal.Insert(true);

        exit(ProposalNo);
    end;

  procedure SetStatus(var VendorProposal: Record "AMC Vendor Proposal"; NewStatus: Enum "AMC Proposal Status")
  var
    VCHPro0001Err: Label 'Vendor proposal status cannot change from %1 to %2.', Comment = '%1 = current proposal status, %2 = requested proposal status';
  begin
    if not this.IsStatusTransitionAllowed(VendorProposal.Status, NewStatus) then
      Error(VCHPro0001Err, VendorProposal.Status, NewStatus);

    VendorProposal.Status := NewStatus;
    VendorProposal.Modify(true);
  end;

  local procedure IsStatusTransitionAllowed(CurrentStatus: Enum "AMC Proposal Status"; NewStatus: Enum "AMC Proposal Status"): Boolean
  begin
    case CurrentStatus of
      CurrentStatus::Draft:
        exit(NewStatus in [NewStatus::Submitted, NewStatus::Withdrawn]);
      CurrentStatus::Submitted:
        exit(NewStatus in [NewStatus::"In Review", NewStatus::Withdrawn, NewStatus::Expired, NewStatus::Superseded]);
      CurrentStatus::"In Review":
        exit(NewStatus in [NewStatus::Approved, NewStatus::Rejected, NewStatus::"Changes Requested", NewStatus::Superseded]);
      CurrentStatus::Approved:
        exit(NewStatus in [NewStatus::Applied, NewStatus::"Apply Failed", NewStatus::Superseded]);
      CurrentStatus::"Apply Failed":
        exit(NewStatus in [NewStatus::Applied, NewStatus::Superseded]);
      CurrentStatus::"Changes Requested":
        exit(NewStatus = NewStatus::Superseded);
    end;
  end;
}
