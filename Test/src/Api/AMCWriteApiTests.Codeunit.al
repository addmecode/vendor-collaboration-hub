namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Vendor;
using System.TestLibraries.Utilities;

codeunit 50147 "AMC Write API Tests"
{
  Subtype = Test;

  [Test]
  procedure GivenFullAnswer_WhenSubmitting_ThenProposalAndLinesAreSubmittedOnce()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    ProposalLine: Record "AMC Vendor Proposal Line";
    IdempotencyKey: Text[64];
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    IdempotencyKey := Format(CreateGuid());
    // When
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    // Then
    this.Assert.IsTrue(Proposal.Get(Proposal."No."), 'The expected proposal record must exist.');
    this.Assert.AreEqual(Proposal.Status::Submitted, Proposal.Status, 'The API must never persist Draft.');
    this.Assert.IsFalse(Proposal."API Submission Pending", 'All nested lines must be finalized.');
    this.Assert.AreEqual(IdempotencyKey, Proposal."Idempotency Key", 'Register the client key only for a valid whole answer.');
    this.Assert.AreEqual(64, StrLen(Proposal."Payload Hash"), 'Persist the canonical SHA-256 hash.');
    this.Assert.IsTrue(Proposal."Submitted Date Time" <> 0DT, 'Stamp submission time.');
    this.Assert.IsTrue(VendorRequest.Get(VendorRequest."No."), 'The expected vendor request record must exist.');
    this.Assert.AreEqual(VendorRequest.Status::"Vendor Responded", VendorRequest.Status, 'Submission moves the request.');
    ProposalLine.SetRange("Proposal No.", Proposal."No.");
    this.Assert.AreEqual(3, ProposalLine.Count(), 'Both splits and the substitution must be saved.');
    this.AssertSubmissionLogs(Proposal."No.");
  end;

  [Test]
  procedure GivenLinesForTwoProposals_WhenFilteringByParentNumber_ThenOnlyOwnLineIsReturned()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    OtherProposal: Record "AMC Vendor Proposal";
    ProposalLine: Record "AMC Vendor Proposal Line";
    OtherProposalLine: Record "AMC Vendor Proposal Line";
    LineView: Record "AMC Vendor Proposal Line";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    // Given: two manually entered lines share a line number under different parents.
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    this.Assert.IsTrue(Proposal.Get(ProposalMgt.CreateDraftFromRequest(VendorRequest)), 'The expected proposal record must exist.');
    this.Assert.IsTrue(OtherProposal.Get(ProposalMgt.CreateDraftFromRequest(VendorRequest)), 'The expected other proposal record must exist.');
    ProposalLine.Init();
    ProposalLine.Validate("Proposal No.", Proposal."No.");
    ProposalLine.Validate("Line No.", 10000);
    ProposalLine.Validate("Request Line No.", 10000);
    ProposalLine.Insert(false);
    OtherProposalLine.Init();
    OtherProposalLine.Validate("Proposal No.", OtherProposal."No.");
    OtherProposalLine.Validate("Line No.", ProposalLine."Line No.");
    OtherProposalLine.Validate("Request Line No.", 10000);
    OtherProposalLine.Insert(false);
    // When: this is the record filter used by the API part's SubPageLink.
    LineView.SetRange("Proposal No.", Proposal."No.");
    // Then: each parent exposes only its own number-linked line.
    this.Assert.AreEqual(1, LineView.Count(), 'The first parent must expose exactly one line.');
    this.Assert.IsTrue(LineView.FindFirst(), 'The first parent line must be reachable.');
    this.Assert.AreEqual(ProposalLine.SystemId, LineView.SystemId, 'Return only the line linked to the first parent.');
    LineView.SetRange("Proposal No.", OtherProposal."No.");
    this.Assert.AreEqual(1, LineView.Count(), 'The second parent must expose exactly one line.');
    this.Assert.IsTrue(LineView.FindFirst(), 'The second parent line must be reachable.');
    this.Assert.AreEqual(OtherProposalLine.SystemId, LineView.SystemId, 'Return only the line linked to the second parent.');
  end;

  [Test]
  procedure GivenInvalidSplitTotal_WhenSubmitting_ThenWritesRollbackAndKeyCanRetry()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    ProposalLine: Record "AMC Vendor Proposal Line";
    Entry: Record "AMC Collaboration Entry";
    IdempotencyKey: Text[64];
    BeforeLineCount: Integer;
    BeforeEntryCount: Integer;
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    // Expected errors roll back the current transaction, not just the attempted submission.
    Commit();
    IdempotencyKey := Format(CreateGuid());
    BeforeLineCount := ProposalLine.Count();
    BeforeEntryCount := Entry.Count();
    // When: the second split takes the total above 1000.
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 600, false, Proposal);
    this.Assert.ExpectedError('VCH-VAL-0012 [line 2/10000]');
    // Then
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    ClearLastError();
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    this.Assert.AreEqual(IdempotencyKey, Proposal."Idempotency Key", 'A rejected answer must release its key.');
    this.AssertSubmissionLogs(Proposal."No.");
  end;

  [Test]
  procedure GivenExistingProposal_WhenReplayingReorderedPayload_ThenExistingIdentityIsReported()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    Replay: Record "AMC Vendor Proposal";
    IdempotencyKey: Text[64];
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit();
    IdempotencyKey := Format(CreateGuid());
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    Commit();
    // When: wire array order is not business identity.
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, true, Replay);
    // Then
    this.Assert.ExpectedError('VCH-IDM-0000');
    this.Assert.ExpectedError(Format(Proposal.SystemId, 0, 4));
    this.Assert.ExpectedError(Proposal."No.");
    this.AssertSingleProposal(VendorRequest."No.");
    this.AssertSubmissionLogs(Proposal."No.");
    ClearLastError();
  end;

  [Test]
  procedure GivenExistingProposal_WhenReusingKeyWithChangedPayload_ThenMismatchIsRejected()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    Replay: Record "AMC Vendor Proposal";
    IdempotencyKey: Text[64];
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit();
    IdempotencyKey := Format(CreateGuid());
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    Commit();
    // When
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 390, false, Replay);
    // Then
    this.Assert.ExpectedError('VCH-IDM-0001');
    this.AssertSingleProposal(VendorRequest."No.");
    this.AssertSubmissionLogs(Proposal."No.");
    ClearLastError();
  end;

  [Test]
  procedure GivenInvalidIdentityOrRequestState_WhenSubmitting_ThenNoProposalIsWritten()
  var
    VendorRequest: Record "AMC Vendor Request";
    OtherRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    OtherToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    Setup: Record "AMC Collaboration Setup";
    Vendor: Record Vendor;
    ProposalLine: Record "AMC Vendor Proposal Line";
    Entry: Record "AMC Collaboration Entry";
    IdempotencyKey: Text[64];
    BeforeLineCount: Integer;
    BeforeEntryCount: Integer;
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    this.TestLibrary.CreateWriteContext(OtherRequest, OtherToken);
    Commit();
    BeforeLineCount := ProposalLine.Count();
    BeforeEntryCount := Entry.Count();
    IdempotencyKey := Format(CreateGuid());
    // When / Then
    this.Assert.IsTrue(Setup.Get(), 'The expected setup record must exist.');
    Setup.Validate(Enabled, false);
    Setup.Modify(false);
    Commit();
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    this.Assert.ExpectedError('VCH-AUT-0001');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    Setup.Validate(Enabled, true);
    Setup.Modify(false);
    this.Assert.IsTrue(Vendor.Get(VendorRequest."Vendor No."), 'The expected vendor record must exist.');
    Vendor.Validate("AMC Collaboration Enabled", false);
    Vendor.Modify(false);
    Commit();
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    this.Assert.ExpectedError('VCH-AUT-0002');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    Vendor.Validate("AMC Collaboration Enabled", true);
    Vendor.Modify(false);
    Commit();
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, OtherToken.SystemId, IdempotencyKey, 400, false, Proposal);
    this.Assert.ExpectedError('VCH-AUT-0004');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    AccessToken.Validate("Expires At", CurrentDateTime() - 1000);
    AccessToken.Modify(false);
    Commit();
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    this.Assert.ExpectedError('VCH-AUT-0003');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    AccessToken.Validate("Expires At", CurrentDateTime() + 3600000);
    AccessToken.Modify(false);
    VendorRequest.Validate(Status, VendorRequest.Status::Draft);
    VendorRequest.Modify(false);
    Commit();
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, IdempotencyKey, 400, false, Proposal);
    this.Assert.ExpectedError('VCH-VAL-0001');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    ClearLastError();
  end;

  [Test]
  procedure GivenMissingKeyOrInternalTokenKey_WhenSubmitting_ThenSubmissionIsRejected()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    ProposalLine: Record "AMC Vendor Proposal Line";
    Entry: Record "AMC Collaboration Entry";
    BeforeLineCount: Integer;
    BeforeEntryCount: Integer;
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit();
    BeforeLineCount := ProposalLine.Count();
    BeforeEntryCount := Entry.Count();
    // When / Then: only the Task 16 API SystemId is an accepted token claim.
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken."Token Id", Format(CreateGuid()), 400, false, Proposal);
    this.Assert.ExpectedError('VCH-AUT-0003');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    asserterror this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, '', 400, false, Proposal);
    this.Assert.ExpectedError('VCH-IDM-0002');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    ClearLastError();
  end;

  [Test]
  procedure GivenMultipleLineFailures_WhenValidating_ThenAllFailuresAndLineMarkerAreRetained()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    Validator: Codeunit "AMC Proposal Validator";
    Result: Codeunit "AMC Validation Result";
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Proposal.Validate("Request No.", VendorRequest."No.");
    Proposal.Validate("Vendor No.", VendorRequest."Vendor No.");
    ProposalMgt.BeginApiSubmission(Proposal, AccessToken.SystemId, Format(CreateGuid()));
    this.TestLibrary.AddAnswerLine(Proposal, 10000, 1, "AMC Proposal Line Type"::Confirm, 0);
    this.TestLibrary.AddAnswerLine(Proposal, 20000, 2, "AMC Proposal Line Type"::Confirm, 600);
    // When
    Validator.Validate(Proposal, Result);
    // Then
    this.Assert.AreEqual(2, Result.GetErrorCount(), 'Validation must retain every failure.');
    this.Assert.IsTrue(StrPos(Result.AsFirstErrorText(), 'VCH-VAL-0010 [line 1/10000]') = 1, 'Render the first stable code and line marker.');
    this.Assert.AreEqual('VCH-VAL-0010,VCH-VAL-0012', Result.GetErrorCodeList(), 'Telemetry must carry the complete code list.');
    this.Assert.IsTrue(StrPos(Result.AsJson(), '20000') > 0, 'The structured result must keep later failures.');
  end;

  [Test]
  procedure GivenInvalidRelatedLineValues_WhenFieldsAreValidated_ThenNativeErrorsLeaveNoWrites()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Line: Record "AMC Vendor Proposal Line";
    Entry: Record "AMC Collaboration Entry";
    BeforeLineCount: Integer;
    BeforeEntryCount: Integer;
  begin
    // Given: field validation precedes the page's insert/domain guards.
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit();
    BeforeLineCount := Line.Count();
    BeforeEntryCount := Entry.Count();

    // When / Then: native relation failures identify the field and rejected value.
    asserterror Line.Validate("Proposed Item No.", 'MISSING-ITEM');
    this.Assert.ExpectedError(Line.FieldCaption("Proposed Item No."));
    this.Assert.ExpectedError('MISSING-ITEM');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);

    Clear(Line);
    Line.Validate("Proposed Item No.", 'ITEM-B2');
    asserterror Line.Validate("Proposed Variant Code", 'MISSING');
    this.Assert.ExpectedError(Line.FieldCaption("Proposed Variant Code"));
    this.Assert.ExpectedError('MISSING');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);

    Clear(Line);
    asserterror Line.Validate("Reason Code", 'MISSING');
    this.Assert.ExpectedError(Line.FieldCaption("Reason Code"));
    this.Assert.ExpectedError('MISSING');
    this.AssertNoSubmissionWrites(VendorRequest, BeforeLineCount, BeforeEntryCount);
    ClearLastError();
  end;

  [Test]
  procedure GivenSubmittedProposal_WhenMutatingOrPostingStandaloneLine_ThenWriteIsRejected()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    Line: Record "AMC Vendor Proposal Line";
    Entry: Record "AMC Collaboration Entry";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    BeforeLineCount: Integer;
    BeforeEntryCount: Integer;
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit();
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, Format(CreateGuid()), 400, false, Proposal);
    Commit();
    BeforeLineCount := Line.Count();
    BeforeEntryCount := Entry.Count();
    Line.Validate("Proposed Item No.", 'ITEM-B2');
    Line.Validate("Proposed Variant Code", '');
    Line.Validate("Reason Code", 'UNAVAIL');
    // When / Then: these are the domain guards called by the page triggers.
    asserterror ProposalMgt.AssertApiWriteOnce();
    this.Assert.ExpectedError('VCH-STA-0001');
    asserterror ProposalMgt.InsertApiLine(Line);
    this.Assert.ExpectedError('VCH-STA-0001');
    this.Assert.AreEqual(BeforeLineCount, Line.Count(), 'A standalone line with valid references must still be rejected.');
    this.Assert.AreEqual(BeforeEntryCount, Entry.Count(), 'A standalone rejection must not write audit entries.');
    Line.Validate("Proposal No.", Proposal."No.");
    asserterror ProposalMgt.InsertApiLine(Line);
    this.Assert.ExpectedError('VCH-STA-0001');
    this.Assert.AreEqual(BeforeLineCount, Line.Count(), 'A navigation POST to a completed proposal must not write a line.');
    this.Assert.AreEqual(BeforeEntryCount, Entry.Count(), 'A navigation rejection must not write audit entries.');
    this.AssertSingleProposal(VendorRequest."No.");
    this.AssertSubmissionLogs(Proposal."No.");
    ClearLastError();
  end;

  local procedure AssertNoSubmissionWrites(VendorRequest: Record "AMC Vendor Request"; BeforeLineCount: Integer; BeforeEntryCount: Integer)
  var
    ProposalLine: Record "AMC Vendor Proposal Line";
    Entry: Record "AMC Collaboration Entry";
    ExpectedStatus: Enum "AMC Request Status";
  begin
    ExpectedStatus := VendorRequest.Status;
    this.AssertSingleRequestHasNoProposals(VendorRequest."No.");
    this.Assert.AreEqual(BeforeLineCount, ProposalLine.Count(), 'Rejected nested lines must be rolled back.');
    this.Assert.AreEqual(BeforeEntryCount, Entry.Count(), 'Rejected answers must not leave success timeline entries.');
    this.Assert.IsTrue(VendorRequest.Get(VendorRequest."No."), 'The committed request fixture must survive a rejected submission.');
    this.Assert.AreEqual(ExpectedStatus, VendorRequest.Status, 'Failure must not move request status.');
  end;

  local procedure AssertSingleRequestHasNoProposals(RequestNo: Code[20])
  var
    Proposal: Record "AMC Vendor Proposal";
  begin
    Proposal.SetRange("Request No.", RequestNo);
    this.Assert.IsTrue(Proposal.IsEmpty(), 'Neither a header nor an idempotency key may survive rejection.');
  end;

  local procedure AssertSingleProposal(RequestNo: Code[20])
  var
    Proposal: Record "AMC Vendor Proposal";
  begin
    Proposal.SetRange("Request No.", RequestNo);
    this.Assert.AreEqual(1, Proposal.Count(), 'A replay must not create another header or consume a durable key.');
  end;

  local procedure AssertSubmissionLogs(ProposalNo: Code[20])
  var
    Entry: Record "AMC Collaboration Entry";
  begin
    Entry.SetRange("Source Type", "AMC Source Type"::Proposal);
    Entry.SetRange("Source No.", ProposalNo);
    Entry.SetRange("Entry Type", "AMC Collab Entry Type"::ProposalReceived);
    this.Assert.AreEqual(1, Entry.Count(), 'Receive exactly once.');
    Entry.SetRange("Entry Type", "AMC Collab Entry Type"::ProposalSubmitted);
    this.Assert.AreEqual(1, Entry.Count(), 'Submit exactly once.');
  end;

  var
    Assert: Codeunit "Library Assert";
    TestLibrary: Codeunit "AMC Test Library";
}
