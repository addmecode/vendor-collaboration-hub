namespace Addmecode.VendorCollaborationHub;

codeunit 50103 "AMC Proposal Decision Svc"
{
  procedure Approve(var VendorProposal: Record "AMC Vendor Proposal"; DecisionReason: Text[250]): Boolean
  var
    ApplySucceeded: Boolean;
    DecisionContext: Record "AMC Vendor Proposal" temporary;
    OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    Telemetry: Codeunit "AMC Telemetry";
    ErrorCode: Code[20];
    ErrorMessage: Text;
    PreviousPurchaseOrderNo: Code[20];
    PreviousRequestNo: Code[20];
    StartedAt: DateTime;
  begin
    VendorProposal.Get(VendorProposal."No.");
    this.VerifyApprovalAllowed(VendorProposal);

    DecisionContext.Init();
    DecisionContext."No." := VendorProposal."No.";
    DecisionContext.Status := DecisionContext.Status::Approved;
    DecisionContext."Decision Reason" := DecisionReason;
    DecisionContext."Decision User ID" := UserId();
    DecisionContext."Correlation Id" := VendorProposal."Correlation Id";
    OrderLockMgt.GetSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
    StartedAt := CurrentDateTime();

    ClearLastError();
    ApplySucceeded := Codeunit.Run(Codeunit::"AMC Apply Proposal Svc", DecisionContext);
    if not ApplySucceeded then begin
      ErrorMessage := GetLastErrorText();
      ErrorCode := this.GetErrorCode(ErrorMessage);
      if ErrorCode = '' then
        ErrorCode := CopyStr(GetLastErrorCode(), 1, MaxStrLen(ErrorCode));
    end;

    OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
    VendorProposal.Get(VendorProposal."No.");
    if ApplySucceeded then begin
      Telemetry.LogProposalApplied(VendorProposal."No.", VendorProposal."Request No.", VendorProposal."Purchase Order No.", this.GetProposalLineCount(VendorProposal."No."), CurrentDateTime() - StartedAt);
      exit(true);
    end;

    this.RecordApplyFailure(VendorProposal, ErrorCode, ErrorMessage);
    VendorProposal.Get(VendorProposal."No.");
    Telemetry.LogProposalApplyFailed(VendorProposal."No.", VendorProposal."Request No.", VendorProposal."Purchase Order No.", ErrorCode, CurrentDateTime() - StartedAt);
    exit(false);
  end;

  procedure Reject(var VendorProposal: Record "AMC Vendor Proposal"; DecisionReason: Text[250])
  var
    CollabLog: Codeunit "AMC Collab Log";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    ProposalRejectedDescriptionLbl: Label 'Vendor proposal rejected.';
  begin
    VendorProposal.Get(VendorProposal."No.");
    this.VerifyInReview(VendorProposal);
    VendorProposal."Decision Date Time" := CurrentDateTime();
    VendorProposal."Decision User ID" := UserId();
    VendorProposal."Decision Reason" := DecisionReason;
    ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::Rejected);
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalRejected, "AMC Actor Type"::Buyer, '', UserId(), false, ProposalRejectedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  procedure RequestChanges(var VendorProposal: Record "AMC Vendor Proposal"; DecisionReason: Text[250])
  var
    CollabLog: Codeunit "AMC Collab Log";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    ChangesRequestedDescriptionLbl: Label 'Changes requested for vendor proposal.';
  begin
    VendorProposal.Get(VendorProposal."No.");
    this.VerifyInReview(VendorProposal);
    VendorProposal."Decision Date Time" := CurrentDateTime();
    VendorProposal."Decision User ID" := UserId();
    VendorProposal."Decision Reason" := DecisionReason;
    ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::"Changes Requested");
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ChangesRequested, "AMC Actor Type"::Buyer, '', UserId(), false, ChangesRequestedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  local procedure VerifyApprovalAllowed(VendorProposal: Record "AMC Vendor Proposal")
  var
    ProposalCannotBeApprovedErr: Label 'Vendor proposal %1 cannot be approved from status %2.', Comment = '%1 = proposal number, %2 = proposal status';
  begin
    if not (VendorProposal.Status in [VendorProposal.Status::"In Review", VendorProposal.Status::"Apply Failed"]) then
      Error(ProposalCannotBeApprovedErr, VendorProposal."No.", VendorProposal.Status);
  end;

  local procedure VerifyInReview(VendorProposal: Record "AMC Vendor Proposal")
  var
    ProposalCannotBeDecidedErr: Label 'Vendor proposal %1 cannot be decided from status %2.', Comment = '%1 = proposal number, %2 = proposal status';
  begin
    if VendorProposal.Status <> VendorProposal.Status::"In Review" then
      Error(ProposalCannotBeDecidedErr, VendorProposal."No.", VendorProposal.Status);
  end;

  local procedure RecordApplyFailure(var VendorProposal: Record "AMC Vendor Proposal"; ErrorCode: Code[20]; ErrorMessage: Text)
  var
    CollabLog: Codeunit "AMC Collab Log";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    ProposalApplyFailedDescriptionLbl: Label 'Vendor proposal apply failed: %1', Comment = '%1 = apply error message';
  begin
    VendorProposal."Apply Attempt Count" += 1;
    VendorProposal."Last Error Code" := ErrorCode;
    VendorProposal."Last Error Message" := CopyStr(ErrorMessage, 1, MaxStrLen(VendorProposal."Last Error Message"));
    if VendorProposal.Status = VendorProposal.Status::"Apply Failed" then
      VendorProposal.Modify(true)
    else
      ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::"Apply Failed");
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalApplyFailed, "AMC Actor Type"::Buyer, '', UserId(), false, CopyStr(StrSubstNo(ProposalApplyFailedDescriptionLbl, ErrorMessage), 1, 250), VendorProposal."Correlation Id");
  end;

  local procedure GetProposalLineCount(ProposalNo: Code[20]): Integer
  var
    VendorProposalLine: Record "AMC Vendor Proposal Line";
  begin
    VendorProposalLine.SetRange("Proposal No.", ProposalNo);
    exit(VendorProposalLine.Count());
  end;

  local procedure GetErrorCode(ErrorMessage: Text): Code[20]
  var
    ErrorCodeStart: Integer;
  begin
    ErrorCodeStart := StrPos(ErrorMessage, 'VCH-');
    if ErrorCodeStart = 0 then
      exit('');

    exit(CopyStr(ErrorMessage, ErrorCodeStart, 12));
  end;
}
