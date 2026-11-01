namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Records buyer decisions, runs proposal application and records failed application attempts.
/// </summary>
codeunit 50103 "AMC Proposal Decision Svc"
{
  Permissions = tabledata "AMC Vendor Proposal" = rm,
                tabledata "AMC Vendor Proposal Line" = r;

  /// <summary>
  /// Approves and applies a proposal from In Review or Apply Failed using an isolated worker and records application failures.
  /// </summary>
  /// <param name="VendorProposal">Identifies the persisted proposal and receives its resulting state.</param>
  /// <param name="DecisionReason">The buyer's reason passed to the application worker.</param>
  /// <returns>True when application succeeds; false when the worker fails and the failure has been recorded.</returns>
  procedure Approve(var VendorProposal: Record "AMC Vendor Proposal"; DecisionReason: Text[250]): Boolean
  var
    TempDecisionContext: Record "AMC Vendor Proposal" temporary;
    OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    Telemetry: Codeunit "AMC Telemetry";
    ApplySucceeded: Boolean;
    ErrorCode: Code[20];
    ErrorMessage: Text;
    PreviousPurchaseOrderNo: Code[20];
    PreviousRequestNo: Code[20];
    StartedAt: DateTime;
  begin
    if not VendorProposal.Get(VendorProposal."No.") then
      Error(this.ProposalNotFoundErr);
    this.VerifyApprovalAllowed(VendorProposal);

    TempDecisionContext.Init();
    // This is an in-memory command envelope; the worker validates and persists the decision.
    TempDecisionContext."No." := VendorProposal."No.";
    TempDecisionContext.Status := TempDecisionContext.Status::Approved;
    TempDecisionContext."Decision Reason" := DecisionReason;
    TempDecisionContext."Decision User ID" := CopyStr(UserId(), 1, MaxStrLen(TempDecisionContext."Decision User ID"));
    TempDecisionContext."Correlation Id" := VendorProposal."Correlation Id";
    OrderLockMgt.GetSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
    StartedAt := CurrentDateTime();

    ClearLastError();
    ApplySucceeded := Codeunit.Run(Codeunit::"AMC Apply Proposal Svc", TempDecisionContext);
    if not ApplySucceeded then begin
      ErrorMessage := GetLastErrorText();
      ErrorCode := this.GetErrorCode(ErrorMessage);
      if ErrorCode = '' then
        ErrorCode := CopyStr(GetLastErrorCode(), 1, MaxStrLen(ErrorCode));
    end;

    OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
    if not VendorProposal.Get(VendorProposal."No.") then
      Error(this.ProposalNotFoundErr);
    if ApplySucceeded then begin
      Telemetry.LogProposalApplied(VendorProposal."No.", VendorProposal."Request No.", VendorProposal."Purchase Order No.", this.GetProposalLineCount(VendorProposal."No."), CurrentDateTime() - StartedAt);
      exit(true);
    end;

    this.RecordApplyFailure(VendorProposal, ErrorCode, ErrorMessage);
    if not VendorProposal.Get(VendorProposal."No.") then
      Error(this.ProposalNotFoundErr);
    Telemetry.LogProposalApplyFailed(VendorProposal."No.", VendorProposal."Request No.", VendorProposal."Purchase Order No.", ErrorCode, CurrentDateTime() - StartedAt);
    exit(false);
  end;

  /// <summary>
  /// Rejects an In Review proposal and records buyer decision metadata and collaboration history.
  /// </summary>
  /// <param name="VendorProposal">Identifies the proposal and receives the rejected state.</param>
  /// <param name="DecisionReason">The reason stored with the buyer's decision.</param>
  procedure Reject(var VendorProposal: Record "AMC Vendor Proposal"; DecisionReason: Text[250])
  var
    CollabLog: Codeunit "AMC Collab Log";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    ProposalRejectedDescriptionLbl: Label 'Vendor proposal rejected.';
  begin
    if not VendorProposal.Get(VendorProposal."No.") then
      Error(this.ProposalNotFoundErr);
    this.VerifyInReview(VendorProposal);
    VendorProposal.Validate("Decision Date Time", CurrentDateTime());
    VendorProposal.Validate("Decision User ID", CopyStr(UserId(), 1, MaxStrLen(VendorProposal."Decision User ID")));
    VendorProposal.Validate("Decision Reason", DecisionReason);
    ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::Rejected);
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalRejected, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), ProposalRejectedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  /// <summary>
  /// Requests changes to an In Review proposal and records buyer decision metadata and history.
  /// </summary>
  /// <param name="VendorProposal">Identifies the proposal and receives the Changes Requested state.</param>
  /// <param name="DecisionReason">The reason stored with the buyer's decision.</param>
  procedure RequestChanges(var VendorProposal: Record "AMC Vendor Proposal"; DecisionReason: Text[250])
  var
    CollabLog: Codeunit "AMC Collab Log";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    ChangesRequestedDescriptionLbl: Label 'Changes requested for vendor proposal.';
  begin
    if not VendorProposal.Get(VendorProposal."No.") then
      Error(this.ProposalNotFoundErr);
    this.VerifyInReview(VendorProposal);
    VendorProposal.Validate("Decision Date Time", CurrentDateTime());
    VendorProposal.Validate("Decision User ID", CopyStr(UserId(), 1, MaxStrLen(VendorProposal."Decision User ID")));
    VendorProposal.Validate("Decision Reason", DecisionReason);
    ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::"Changes Requested");
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ChangesRequested, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), ChangesRequestedDescriptionLbl, VendorProposal."Correlation Id");
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
    VendorProposal.Validate("Apply Attempt Count", VendorProposal."Apply Attempt Count" + 1);
    VendorProposal.Validate("Last Error Code", ErrorCode);
    VendorProposal.Validate("Last Error Message", CopyStr(ErrorMessage, 1, MaxStrLen(VendorProposal."Last Error Message")));
    if VendorProposal.Status = VendorProposal.Status::"Apply Failed" then
      VendorProposal.Modify(true)
    else
      ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::"Apply Failed");
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalApplyFailed, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), CopyStr(StrSubstNo(ProposalApplyFailedDescriptionLbl, ErrorMessage), 1, 250), VendorProposal."Correlation Id");
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

  var
    ProposalNotFoundErr: Label 'The vendor proposal could not be found. Refresh the document and try again.';
}
