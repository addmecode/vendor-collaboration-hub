namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using Microsoft.Purchases.Vendor;

codeunit 50101 "AMC Proposal Mgt"
{
  Permissions = tabledata "AMC Collaboration Setup" = r,
                tabledata "AMC Vendor Access Token" = r,
                tabledata "AMC Vendor Proposal" = rim,
                tabledata "AMC Vendor Proposal Line" = ri,
                tabledata "AMC Vendor Request" = r,
                tabledata Vendor = r;

  [CommitBehavior(CommitBehavior::Error)]
  procedure BeginApiSubmission(var VendorProposal: Record "AMC Vendor Proposal"; AccessTokenId: Guid; IdempotencyKey: Text[64])
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    NoSeries: Codeunit "No. Series";
    KeyRequiredErr: Label 'VCH-IDM-0002: An idempotency key is required.';
    NumberSeriesRequiredErr: Label 'VCH-AUT-0001: A proposal number series must be configured before submitting a proposal.';
  begin
    this.AssertApiIdentity(AccessTokenId, VendorProposal."Request No.", VendorProposal."Vendor No.");
    if IdempotencyKey = '' then
      Error(KeyRequiredErr);
    if not CollaborationSetup.Get() then
      Error(NumberSeriesRequiredErr);
    if CollaborationSetup."Proposal Nos." = '' then
      Error(NumberSeriesRequiredErr);

    // The runtime inserts the parent before its children. Stage only within this
    // transaction; the page's post-insert read completes the whole deep insert.
    VendorProposal.LockTable();
    VendorProposal."No." := NoSeries.GetNextNo(CollaborationSetup."Proposal Nos.", WorkDate(), true);
    if VendorProposal."No." = '' then
      Error(NumberSeriesRequiredErr);
    VendorProposal."Idempotency Key" := Format(CreateGuid(), 0, 4);
    VendorProposal.Status := VendorProposal.Status::Submitted;
    VendorProposal."API Submission Pending" := true;
    VendorProposal."Submitted Date Time" := 0DT;
    VendorProposal."Payload Hash" := '';
    if IsNullGuid(VendorProposal."Correlation Id") then
      VendorProposal."Correlation Id" := CreateGuid();
    if IsNullGuid(VendorProposal.SystemId) then
      VendorProposal.SystemId := CreateGuid();
    VendorProposal.Insert(true, true);
  end;

  procedure AssertApiIdentity(AccessTokenId: Guid; RequestNo: Code[20]; VendorNo: Code[20])
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    Vendor: Record Vendor;
    VendorAccessToken: Record "AMC Vendor Access Token";
    AccessTokenMgt: Codeunit "AMC Access Token Mgt";
    SetupDisabledErr: Label 'VCH-AUT-0001: Vendor collaboration is not enabled in setup.';
    VendorDisabledErr: Label 'VCH-AUT-0002: The vendor is not enabled for collaboration.';
    TokenInvalidErr: Label 'VCH-AUT-0003: This access link is no longer valid.';
  begin
    CollaborationSetup.SetLoadFields(Enabled);
    if not CollaborationSetup.Get() then
      Error(SetupDisabledErr);
    if not CollaborationSetup.Enabled then
      Error(SetupDisabledErr);
    Vendor.SetLoadFields("AMC Collaboration Enabled");
    if not Vendor.Get(VendorNo) then
      Error(VendorDisabledErr);
    if not Vendor."AMC Collaboration Enabled" then
      Error(VendorDisabledErr);
    // The Task 16 API exposes SystemId, whereas the token domain's primary key
    // is Token Id. Translate the API identity; never accept an alternate key.
    VendorAccessToken.SetLoadFields("Token Id");
    if not VendorAccessToken.GetBySystemId(AccessTokenId) then
      Error(TokenInvalidErr);
    AccessTokenMgt.Assert(VendorAccessToken."Token Id", RequestNo, VendorNo);
  end;

  [CommitBehavior(CommitBehavior::Error)]
  procedure CompleteApiSubmission(var VendorProposal: Record "AMC Vendor Proposal"; AccessTokenId: Guid; IdempotencyKey: Text[64])
  var
    VendorRequest: Record "AMC Vendor Request";
    ProposalLine: Record "AMC Vendor Proposal Line";
    IdempotencyMgt: Codeunit "AMC Idempotency Mgt";
    ProposalValidator: Codeunit "AMC Proposal Validator";
    Result: Codeunit "AMC Validation Result";
    RequestMgt: Codeunit "AMC Request Mgt";
    CollabLog: Codeunit "AMC Collab Log";
    Telemetry: Codeunit "AMC Telemetry";
    BusinessEvents: Codeunit "AMC Business Events";
    ReceivedLbl: Label 'Vendor proposal received.';
    SubmittedLbl: Label 'Vendor proposal submitted.';
    PendingRequiredErr: Label 'VCH-STA-0001: Only an active deep insert can submit a proposal through the API.';
  begin
    VendorProposal.Get(VendorProposal."No.");
    if not VendorProposal."API Submission Pending" then
      Error(PendingRequiredErr);
    this.AssertApiIdentity(AccessTokenId, VendorProposal."Request No.", VendorProposal."Vendor No.");
    IdempotencyMgt.Register(VendorProposal, IdempotencyKey, IdempotencyMgt.HashPayload(VendorProposal, AccessTokenId));
    VendorRequest.LockTable();
    this.AssertApiRequest(VendorProposal."Request No.", VendorProposal."Vendor No.", VendorRequest);
    VendorProposal."Purchase Order No." := VendorRequest."Purchase Order No.";
    this.ValidateApiLineStructure(VendorProposal, Result);
    ProposalValidator.Validate(VendorProposal, Result);
    if Result.HasErrors() then begin
      Telemetry.LogProposalValidationFailed(VendorProposal, Result);
      Error(Result.AsFirstErrorText());
    end;

    if IsNullGuid(VendorProposal."Correlation Id") then
      VendorProposal."Correlation Id" := CreateGuid();
    VendorProposal."Submitted Date Time" := CurrentDateTime();
    VendorProposal."API Submission Pending" := false;
    VendorProposal.Modify(true);
    this.SupersedePreviousProposals(VendorProposal);
    if VendorRequest.Status = VendorRequest.Status::"Awaiting Vendor" then
      RequestMgt.SetStatus(VendorRequest, VendorRequest.Status::"Vendor Responded");
    ProposalLine.SetRange("Proposal No.", VendorProposal."No.");
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalReceived, "AMC Actor Type"::Vendor, VendorProposal."Submitted By", '', ReceivedLbl, VendorProposal."Correlation Id");
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalSubmitted, "AMC Actor Type"::Vendor, VendorProposal."Submitted By", '', SubmittedLbl, VendorProposal."Correlation Id");
    Telemetry.LogProposalSubmitted(VendorProposal, ProposalLine.Count());
    BusinessEvents.VendorProposalSubmitted(VendorProposal."No.", VendorProposal."Vendor No.", VendorProposal."Purchase Order No.", VendorProposal."Request No.");
  end;

  procedure AssertApiRequest(RequestNo: Code[20]; VendorNo: Code[20]; var VendorRequest: Record "AMC Vendor Request")
  var
    RequestNotOpenErr: Label 'VCH-VAL-0001: The request does not exist, belongs to another vendor, or is not open for a vendor response.';
  begin
    if not VendorRequest.Get(RequestNo) then
      Error(RequestNotOpenErr);
    if (VendorRequest."Vendor No." <> VendorNo) or
       not (VendorRequest.Status in [VendorRequest.Status::"Awaiting Vendor", VendorRequest.Status::"Vendor Responded", VendorRequest.Status::"In Review"]) then
      Error(RequestNotOpenErr);
  end;

  [CommitBehavior(CommitBehavior::Error)]
  procedure InsertApiLine(var ProposalLine: Record "AMC Vendor Proposal Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
    LastLine: Record "AMC Vendor Proposal Line";
    NestedOnlyErr: Label 'VCH-STA-0001: Proposal lines can only be created inside a vendorProposals deep insert.';
  begin
    VendorProposal.SetLoadFields("No.", "API Submission Pending", Status);
    if not VendorProposal.Get(ProposalLine."Proposal No.") then
      Error(NestedOnlyErr);
    if not VendorProposal."API Submission Pending" or (VendorProposal.Status <> VendorProposal.Status::Submitted) then
      Error(NestedOnlyErr);
    LastLine.SetRange("Proposal No.", VendorProposal."No.");
    LastLine.SetLoadFields("Line No.");
    ProposalLine."Line No." := 10000;
    if LastLine.FindLast() then
      ProposalLine."Line No." := LastLine."Line No." + 10000;
    if IsNullGuid(ProposalLine.SystemId) then
      ProposalLine.SystemId := CreateGuid();
    ProposalLine.Insert(true, true);
  end;

  procedure AssertApiWriteOnce()
  var
    WriteOnceErr: Label 'VCH-STA-0001: Proposals and their lines are write-once through the API; update and delete are not supported.';
  begin
    Error(WriteOnceErr);
  end;

  local procedure ValidateApiLineStructure(VendorProposal: Record "AMC Vendor Proposal"; var Result: Codeunit "AMC Validation Result")
  var
    ProposalLine: Record "AMC Vendor Proposal Line";
    PreviousRequestLineNo: Integer;
    PreviousSequenceNo: Integer;
    HasPreviousLine: Boolean;
    PayloadCodeLbl: Label 'VCH-VAL-0001', Locked = true;
    LinesRequiredErr: Label 'A proposal must contain at least one line.';
    SequenceErr: Label 'Request line and sequence numbers must be positive and each request-line/sequence pair must be unique.';
  begin
    ProposalLine.SetCurrentKey("Proposal No.", "Request Line No.", "Sequence No.");
    ProposalLine.SetRange("Proposal No.", VendorProposal."No.");
    if not ProposalLine.FindSet() then begin
      Result.AddError(PayloadCodeLbl, 0, 0, LinesRequiredErr);
      exit;
    end;
    repeat
      if (ProposalLine."Request Line No." <= 0) or (ProposalLine."Sequence No." <= 0) or
         (HasPreviousLine and (PreviousRequestLineNo = ProposalLine."Request Line No.") and (PreviousSequenceNo = ProposalLine."Sequence No.")) then
        Result.AddError(PayloadCodeLbl, ProposalLine."Request Line No.", ProposalLine."Sequence No.", SequenceErr);
      HasPreviousLine := true;
      PreviousRequestLineNo := ProposalLine."Request Line No.";
      PreviousSequenceNo := ProposalLine."Sequence No.";
    until ProposalLine.Next() = 0;
  end;

  local procedure SupersedePreviousProposals(VendorProposal: Record "AMC Vendor Proposal")
  var
    PreviousProposal: Record "AMC Vendor Proposal";
    CollabLog: Codeunit "AMC Collab Log";
    SupersededLbl: Label 'Vendor proposal superseded by %1.', Comment = '%1 = new proposal number';
  begin
    PreviousProposal.SetRange("Request No.", VendorProposal."Request No.");
    PreviousProposal.SetFilter("No.", '<>%1', VendorProposal."No.");
    PreviousProposal.SetFilter(Status, '%1|%2|%3', PreviousProposal.Status::Submitted, PreviousProposal.Status::"In Review", PreviousProposal.Status::"Changes Requested");
    if PreviousProposal.FindSet(true) then
      repeat
        PreviousProposal."Superseded By" := VendorProposal."No.";
        this.SetStatus(PreviousProposal, PreviousProposal.Status::Superseded);
        CollabLog.LogEvent("AMC Source Type"::Proposal, PreviousProposal."No.", 0, "AMC Collab Entry Type"::ProposalSuperseded, "AMC Actor Type"::Vendor, VendorProposal."Submitted By", '', StrSubstNo(SupersededLbl, VendorProposal."No."), VendorProposal."Correlation Id");
      until PreviousProposal.Next() = 0;
  end;

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
    VendorProposal.Modify(false);
  end;

  local procedure IsStatusTransitionAllowed(CurrentStatus: Enum "AMC Proposal Status"; NewStatus: Enum "AMC Proposal Status"): Boolean
  begin
    case CurrentStatus of
      CurrentStatus::Draft:
        exit(NewStatus in [NewStatus::Submitted, NewStatus::Withdrawn]);
      CurrentStatus::Submitted:
        exit(NewStatus in [NewStatus::"In Review", NewStatus::Withdrawn, NewStatus::Expired, NewStatus::Superseded]);
       CurrentStatus::"In Review":
        exit(NewStatus in [NewStatus::Approved, NewStatus::Rejected, NewStatus::"Changes Requested", NewStatus::"Apply Failed", NewStatus::Superseded]);
      CurrentStatus::Approved:
        exit(NewStatus in [NewStatus::Applied, NewStatus::"Apply Failed", NewStatus::Superseded]);
      CurrentStatus::"Apply Failed":
        exit(NewStatus in [NewStatus::Approved, NewStatus::Applied, NewStatus::Superseded]);
      CurrentStatus::"Changes Requested":
        exit(NewStatus = NewStatus::Superseded);
    end;
  end;
}
