namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.TestLibraries.Utilities;

codeunit 50132 "AMC Collab Log Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenTimelinePage_WhenOpened_ThenItIsNotEditable()
    var
        CollabTimeline: TestPage "AMC Collab Timeline";
    begin
        // Given

        // When
        CollabTimeline.OpenView();

        // Then
        this.Assert.IsFalse(CollabTimeline.Editable(), 'The collaboration timeline must not be editable.');
        CollabTimeline.Close();
    end;

    [Test]
    procedure GivenLoggedEntry_WhenModified_ThenModificationIsRejected()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        EntryNo: BigInteger;
    begin
        // Given
        EntryNo := this.LogEntry("AMC Collab Entry Type"::Comment);
        CollaborationEntry.Get(EntryNo);
        CollaborationEntry.Description := 'Changed description.';

        // When
        asserterror CollaborationEntry.Modify(true);

        // Then
        this.Assert.ExpectedError('Collaboration entries cannot be modified.');
    end;

    [Test]
    procedure GivenLoggedEntry_WhenDeleted_ThenDeletionIsRejected()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        EntryNo: BigInteger;
    begin
        // Given
        EntryNo := this.LogEntry("AMC Collab Entry Type"::RequestCreated);
        CollaborationEntry.Get(EntryNo);

        // When
        asserterror CollaborationEntry.Delete(true);

        // Then
        this.Assert.ExpectedError('Collaboration entries cannot be deleted.');
    end;

    [Test]
    procedure GivenTelemetryDimensions_WhenMessageIsLogged_ThenEventIdDimensionIsAdded()
    var
        Telemetry: Codeunit "AMC Telemetry";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        // Given
        CustomDimensions.Add('vchRequestNo', this.CreateRequestNo());

        // When
        Telemetry.LogMessage('VCH0101', 'Vendor request created.', Verbosity::Normal, CustomDimensions);

        // Then
        this.Assert.IsTrue(CustomDimensions.ContainsKey('vchEventId'), 'Telemetry must include the logical event-id dimension.');
        this.Assert.AreEqual('VCH0101', CustomDimensions.Get('vchEventId'), 'The logical event-id dimension must match the emitted event id.');
    end;

  [Test]
  procedure GivenLogWrappers_WhenWritingMixedHistory_ThenCommentsAndEventsKeepTheirAuditData()
  var
    Entry: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
    SourceNo: Code[20];
    CorrelationId: Guid;
  begin
    // Given
    SourceNo := this.CreateRequestNo();
    CorrelationId := CreateGuid();
    // When: comments have no visibility choice; events remain in internal history.
    CollabLog.LogComment("AMC Source Type"::Request, SourceNo, 0, "AMC Actor Type"::Buyer, 'Buyer', 'BUYER', 'Vendor-facing comment.', CorrelationId);
    CollabLog.LogEvent("AMC Source Type"::Request, SourceNo, 0, "AMC Collab Entry Type"::RequestCreated, "AMC Actor Type"::System, '', '', 'Request created.', CorrelationId);
    CollabLog.LogFieldChange("AMC Source Type"::Request, SourceNo, 10000, "AMC Collab Entry Type"::ProposalApplied, "AMC Actor Type"::Buyer, 'Buyer', 'BUYER', 'Quantity', '400', '500', 'Quantity applied.', CorrelationId);
    // Then
    Entry.SetRange("Source Type", "AMC Source Type"::Request);
    Entry.SetRange("Source No.", SourceNo);
    this.Assert.AreEqual(3, Entry.Count(), 'Every wrapper appends one entry to the same mixed history.');
    Entry.SetRange("Correlation Id", CorrelationId);
    this.Assert.AreEqual(3, Entry.Count(), 'All wrappers preserve the correlation ID.');
    Entry.SetRange("Entry Type", "AMC Collab Entry Type"::Comment);
    Entry.FindFirst();
    this.Assert.AreEqual('Vendor-facing comment.', Entry.Description, 'Keep the comment text.');
    this.Assert.AreEqual("AMC Actor Type"::Buyer, Entry."Actor Type", 'Keep the comment author type.');
    this.Assert.AreEqual('Buyer', Entry."Actor Name", 'Keep the comment author name.');
    this.Assert.AreEqual('BUYER', Entry."User ID", 'Keep the internal author identity.');
    this.Assert.IsTrue(Entry."Date Time" <> 0DT, 'Stamp the comment time.');
    Entry.SetRange("Entry Type", "AMC Collab Entry Type"::RequestCreated);
    Entry.FindFirst();
    this.Assert.AreEqual('Request created.', Entry.Description, 'Keep the internal event description.');
    this.Assert.AreEqual("AMC Actor Type"::System, Entry."Actor Type", 'Keep the event actor type.');
    this.Assert.IsTrue(Entry."Date Time" <> 0DT, 'Stamp the event time.');
    Entry.SetRange("Entry Type", "AMC Collab Entry Type"::ProposalApplied);
    Entry.FindFirst();
    this.Assert.AreEqual(10000, Entry."Source Line No.", 'Keep the field-change source line.');
    this.Assert.AreEqual('Quantity', Entry."Field Name", 'Keep the changed field.');
    this.Assert.AreEqual('400', Entry."Old Value", 'Keep the previous value.');
    this.Assert.AreEqual('500', Entry."New Value", 'Keep the applied value.');
    this.Assert.AreEqual('Quantity applied.', Entry.Description, 'Keep the field-change description.');
    this.Assert.IsTrue(Entry."Date Time" <> 0DT, 'Stamp the field-change time.');
  end;

  [Test]
  procedure GivenProposalEntries_WhenNavigating_ThenTimelineFollowsProposal()
  var
    FirstProposal: Record "AMC Vendor Proposal";
    SecondProposal: Record "AMC Vendor Proposal";
    EmptyProposal: Record "AMC Vendor Proposal";
    ProposalPage: TestPage "AMC Vendor Proposal";
  begin
    // Given: a request with the same number must not leak into the proposal timeline.
    this.CreatePageProposal(FirstProposal);
    this.CreatePageProposal(SecondProposal);
    this.CreatePageProposal(EmptyProposal);
    this.LogPageEntry("AMC Source Type"::Proposal, FirstProposal."No.", "AMC Collab Entry Type"::Comment, 'First proposal.', CreateGuid());
    this.LogPageEntry("AMC Source Type"::Proposal, SecondProposal."No.", "AMC Collab Entry Type"::Comment, 'Second proposal.', CreateGuid());
    this.LogPageEntry("AMC Source Type"::Request, FirstProposal."No.", "AMC Collab Entry Type"::Comment, 'Unrelated request.', CreateGuid());

    // When
    ProposalPage.OpenEdit();
    ProposalPage.Filter.SetFilter("No.", StrSubstNo('%1|%2|%3', FirstProposal."No.", SecondProposal."No.", EmptyProposal."No."));
    ProposalPage.GoToRecord(FirstProposal);

    // Then
    this.Assert.IsTrue(ProposalPage.CollabTimeline.First(), 'The first proposal must have a timeline entry.');
    ProposalPage.CollabTimeline.Description.AssertEquals('First proposal.');
    this.Assert.IsFalse(ProposalPage.CollabTimeline.Description.Editable(), 'The embedded timeline must remain read-only on an editable proposal.');
    this.Assert.IsFalse(ProposalPage.CollabTimeline.Next(), 'Only entries belonging to the active proposal may appear.');

    ProposalPage.GoToRecord(SecondProposal);
    this.Assert.IsTrue(ProposalPage.CollabTimeline.First(), 'Navigation must load the second proposal timeline.');
    ProposalPage.CollabTimeline.Description.AssertEquals('Second proposal.');
    this.Assert.IsFalse(ProposalPage.CollabTimeline.Next(), 'The first proposal entry must not remain after navigation.');

    ProposalPage.GoToRecord(EmptyProposal);
    this.Assert.IsFalse(ProposalPage.CollabTimeline.First(), 'A proposal without entries must not retain stale timeline rows.');
    ProposalPage.GoToRecord(FirstProposal);
    this.Assert.IsTrue(ProposalPage.CollabTimeline.First(), 'Returning from an empty timeline must restore the matching entry.');
    ProposalPage.CollabTimeline.Description.AssertEquals('First proposal.');
    ProposalPage.Close();
  end;

  [Test]
  procedure GivenDatedProposalEntries_WhenOpened_ThenNewestIsFirst()
  var
    VendorProposal: Record "AMC Vendor Proposal";
    ProposalPage: TestPage "AMC Vendor Proposal";
    OldestDateTime: DateTime;
    MiddleDateTime: DateTime;
    NewestDateTime: DateTime;
  begin
    // Given: immutable records receive deterministic times on insertion, not by modification.
    this.CreatePageProposal(VendorProposal);
    OldestDateTime := CreateDateTime(20260115D, 100000T);
    MiddleDateTime := CreateDateTime(20260115D, 110000T);
    NewestDateTime := CreateDateTime(20260115D, 120000T);
    this.InsertDatedEntry("AMC Source Type"::Proposal, VendorProposal."No.", "AMC Collab Entry Type"::ProposalReceived, OldestDateTime);
    this.InsertDatedEntry("AMC Source Type"::Proposal, VendorProposal."No.", "AMC Collab Entry Type"::ProposalApplied, NewestDateTime);
    this.InsertDatedEntry("AMC Source Type"::Proposal, VendorProposal."No.", "AMC Collab Entry Type"::Comment, MiddleDateTime);

    // When
    ProposalPage.OpenView();
    ProposalPage.GoToRecord(VendorProposal);

    // Then
    this.Assert.IsTrue(ProposalPage.CollabTimeline.First(), 'The timeline must contain the newest entry.');
    ProposalPage.CollabTimeline."Date Time".AssertEquals(NewestDateTime);
    ProposalPage.CollabTimeline."Entry Type".AssertEquals("AMC Collab Entry Type"::ProposalApplied);
    this.Assert.IsTrue(ProposalPage.CollabTimeline.Next(), 'The timeline must contain the middle entry.');
    ProposalPage.CollabTimeline."Date Time".AssertEquals(MiddleDateTime);
    ProposalPage.CollabTimeline."Entry Type".AssertEquals("AMC Collab Entry Type"::Comment);
    this.Assert.IsTrue(ProposalPage.CollabTimeline.Next(), 'The timeline must contain the oldest entry.');
    ProposalPage.CollabTimeline."Date Time".AssertEquals(OldestDateTime);
    ProposalPage.CollabTimeline."Entry Type".AssertEquals("AMC Collab Entry Type"::ProposalReceived);
    this.Assert.IsFalse(ProposalPage.CollabTimeline.Editable(), 'Mixed comment and event history remains read-only.');
    this.Assert.IsFalse(ProposalPage.CollabTimeline.Next(), 'Only the three matching entries may appear.');
    ProposalPage.Close();
  end;

  [Test]
  procedure GivenEntryList_WhenOpenedForEditing_ThenFieldsAreVisibleAndReadOnly()
  var
    TestLibrary: Codeunit "AMC Test Library";
    EntriesPage: TestPage "AMC Collaboration Entries";
    SourceNo: Code[20];
    CorrelationId: Guid;
  begin
    // Given
    SourceNo := TestLibrary.NewCode();
    CorrelationId := CreateGuid();
    this.LogPageEntry("AMC Source Type"::Proposal, SourceNo, "AMC Collab Entry Type"::Comment, 'Inspect this entry.', CorrelationId);

    // When: OpenView alone would not prove the page rejects editing.
    EntriesPage.OpenEdit();
    EntriesPage.Filter.SetFilter("Source No.", SourceNo);

    // Then
    this.Assert.IsTrue(EntriesPage.First(), 'The all-entry list must display the logged record.');
    this.Assert.IsFalse(EntriesPage.Editable(), 'The all-entry list must not allow editing.');
    this.Assert.IsTrue(EntriesPage."Source Type".Visible(), 'Source Type must be visible.');
    this.Assert.IsTrue(EntriesPage."Source No.".Visible(), 'Source No. must be visible.');
    this.Assert.IsTrue(EntriesPage."Entry Type".Visible(), 'Entry Type must be visible.');
    this.Assert.IsTrue(EntriesPage."Date Time".Visible(), 'Date Time must be visible.');
    this.Assert.IsTrue(EntriesPage."Correlation Id".Visible(), 'Correlation Id must be visible.');
    EntriesPage."Source Type".AssertEquals("AMC Source Type"::Proposal);
    EntriesPage."Source No.".AssertEquals(SourceNo);
    EntriesPage."Entry Type".AssertEquals("AMC Collab Entry Type"::Comment);
    EntriesPage."Correlation Id".AssertEquals(CorrelationId);
    EntriesPage.Description.AssertEquals('Inspect this entry.');
    this.Assert.IsFalse(EntriesPage.Next(), 'Only the unique fixture record may match.');
    EntriesPage.Close();
  end;

  [Test]
  procedure GivenMixedSources_WhenListIsFiltered_ThenOnlyMatchingSourcesRemain()
  var
    TestLibrary: Codeunit "AMC Test Library";
    EntriesPage: TestPage "AMC Collaboration Entries";
    SharedSourceNo: Code[20];
    OtherSourceNo: Code[20];
    CorrelationId: Guid;
  begin
    // Given: a unique correlation scopes the fixture without masking either source filter.
    SharedSourceNo := TestLibrary.NewCode();
    OtherSourceNo := TestLibrary.NewCode();
    CorrelationId := CreateGuid();
    this.LogPageEntry("AMC Source Type"::Request, SharedSourceNo, "AMC Collab Entry Type"::Comment, 'Request.', CorrelationId);
    this.LogPageEntry("AMC Source Type"::Proposal, SharedSourceNo, "AMC Collab Entry Type"::Comment, 'Proposal.', CorrelationId);
    this.LogPageEntry("AMC Source Type"::Proposal, OtherSourceNo, "AMC Collab Entry Type"::Comment, 'Other proposal.', CorrelationId);

    // When / Then: Source Type alone retains both proposals, not the request.
    EntriesPage.OpenView();
    EntriesPage.Filter.SetFilter("Correlation Id", Format(CorrelationId));
    EntriesPage.Filter.SetFilter("Source Type", Format("AMC Source Type"::Proposal));
    this.Assert.IsTrue(EntriesPage.First(), 'The first proposal must match the source type filter.');
    EntriesPage."Source Type".AssertEquals("AMC Source Type"::Proposal);
    this.Assert.IsTrue(EntriesPage.Next(), 'Source type alone must retain the other proposal.');
    EntriesPage."Source Type".AssertEquals("AMC Source Type"::Proposal);
    this.Assert.IsFalse(EntriesPage.Next(), 'The request must be excluded by source type.');

    // Both source filters must intersect.
    EntriesPage.Filter.SetFilter("Source No.", SharedSourceNo);
    this.Assert.IsTrue(EntriesPage.First(), 'The proposal with the selected number must match.');
    EntriesPage.Description.AssertEquals('Proposal.');
    this.Assert.IsFalse(EntriesPage.Next(), 'The intersection must exclude the request and the other proposal.');

    // Clearing Source Type proves Source No. independently includes either document type.
    EntriesPage.Filter.SetFilter("Source Type", '');
    this.Assert.IsTrue(EntriesPage.First(), 'The shared source number must have an entry.');
    EntriesPage."Source No.".AssertEquals(SharedSourceNo);
    this.Assert.IsTrue(EntriesPage.Next(), 'Both document types with the shared number must match.');
    EntriesPage."Source No.".AssertEquals(SharedSourceNo);
    this.Assert.IsFalse(EntriesPage.Next(), 'The other source number must be excluded.');
    EntriesPage.Filter.SetFilter("Source No.", TestLibrary.NewCode());
    this.Assert.IsFalse(EntriesPage.First(), 'An unmatched source number must produce an empty list.');
    EntriesPage.Close();
  end;

  [Test]
  procedure GivenEntryTypes_WhenListIsFiltered_ThenOnlyMatchingTypeRemains()
  var
    TestLibrary: Codeunit "AMC Test Library";
    EntriesPage: TestPage "AMC Collaboration Entries";
    SourceNo: Code[20];
  begin
    // Given
    SourceNo := TestLibrary.NewCode();
    this.LogPageEntry("AMC Source Type"::Proposal, SourceNo, "AMC Collab Entry Type"::Comment, 'Comment.', CreateGuid());
    this.LogPageEntry("AMC Source Type"::Proposal, SourceNo, "AMC Collab Entry Type"::ProposalReceived, 'Received.', CreateGuid());

    // When
    EntriesPage.OpenEdit();
    EntriesPage.Filter.SetFilter("Source No.", SourceNo);
    this.Assert.IsTrue(EntriesPage.First(), 'The internal list must include mixed history.');
    this.Assert.IsFalse(EntriesPage.Editable(), 'Mixed history must remain read-only.');
    this.Assert.IsTrue(EntriesPage.Next(), 'Both the comment and the internal event must remain in the list.');
    this.Assert.IsFalse(EntriesPage.Next(), 'Only the two fixture entries may appear.');
    EntriesPage.Filter.SetFilter("Entry Type", Format("AMC Collab Entry Type"::ProposalReceived));

    // Then
    this.Assert.IsTrue(EntriesPage.First(), 'The selected event type must match.');
    EntriesPage."Entry Type".AssertEquals("AMC Collab Entry Type"::ProposalReceived);
    this.Assert.IsFalse(EntriesPage.Next(), 'Entries of another type must be excluded.');
    EntriesPage.Close();
  end;

  [Test]
  procedure GivenCorrelations_WhenListIsFiltered_ThenOnlyMatchingCorrelationRemains()
  var
    TestLibrary: Codeunit "AMC Test Library";
    EntriesPage: TestPage "AMC Collaboration Entries";
    SourceNo: Code[20];
    MatchingCorrelationId: Guid;
    OtherCorrelationId: Guid;
  begin
    // Given
    SourceNo := TestLibrary.NewCode();
    MatchingCorrelationId := CreateGuid();
    OtherCorrelationId := CreateGuid();
    this.LogPageEntry("AMC Source Type"::Proposal, SourceNo, "AMC Collab Entry Type"::Comment, 'Matching correlation.', MatchingCorrelationId);
    this.LogPageEntry("AMC Source Type"::Proposal, SourceNo, "AMC Collab Entry Type"::Comment, 'Other correlation.', OtherCorrelationId);

    // When: no source filter is needed for a unique correlation ID.
    EntriesPage.OpenView();
    EntriesPage.Filter.SetFilter("Correlation Id", Format(MatchingCorrelationId));

    // Then
    this.Assert.IsTrue(EntriesPage.First(), 'The selected correlation ID must match.');
    EntriesPage."Correlation Id".AssertEquals(MatchingCorrelationId);
    this.Assert.IsFalse(EntriesPage.Next(), 'Entries of another correlation must be excluded.');
    EntriesPage.Filter.SetFilter("Correlation Id", Format(OtherCorrelationId));
    this.Assert.IsTrue(EntriesPage.First(), 'Changing correlation must load the other entry.');
    EntriesPage."Correlation Id".AssertEquals(OtherCorrelationId);
    this.Assert.IsFalse(EntriesPage.Next(), 'The previous correlation must no longer match.');
    EntriesPage.Filter.SetFilter("Correlation Id", Format(CreateGuid()));
    this.Assert.IsFalse(EntriesPage.First(), 'An unmatched correlation must produce an empty list.');
    EntriesPage.Close();
  end;

  [Test]
  procedure GivenDatedEntries_WhenListIsFiltered_ThenRangeIsInclusive()
  var
    TestLibrary: Codeunit "AMC Test Library";
    EntriesPage: TestPage "AMC Collaboration Entries";
    SourceNo: Code[20];
    LowerDateTime: DateTime;
    MiddleDateTime: DateTime;
    UpperDateTime: DateTime;
  begin
    // Given: include a record just outside each boundary as well as one inside.
    SourceNo := TestLibrary.NewCode();
    LowerDateTime := CreateDateTime(20260115D, 100000T);
    MiddleDateTime := CreateDateTime(20260115D, 110000T);
    UpperDateTime := CreateDateTime(20260115D, 120000T);
    this.InsertDatedEntry("AMC Source Type"::Request, SourceNo, "AMC Collab Entry Type"::RequestCreated, LowerDateTime - 1000);
    this.InsertDatedEntry("AMC Source Type"::Request, SourceNo, "AMC Collab Entry Type"::RequestCreated, LowerDateTime);
    this.InsertDatedEntry("AMC Source Type"::Request, SourceNo, "AMC Collab Entry Type"::Comment, MiddleDateTime);
    this.InsertDatedEntry("AMC Source Type"::Request, SourceNo, "AMC Collab Entry Type"::RequestSent, UpperDateTime);
    this.InsertDatedEntry("AMC Source Type"::Request, SourceNo, "AMC Collab Entry Type"::RequestSent, UpperDateTime + 1000);

    // When
    EntriesPage.OpenView();
    EntriesPage.Filter.SetFilter("Source No.", SourceNo);
    EntriesPage.Filter.SetFilter("Date Time", StrSubstNo('%1..%2', LowerDateTime, UpperDateTime));

    // Then
    this.Assert.IsTrue(EntriesPage.First(), 'The inclusive upper boundary must match.');
    EntriesPage."Date Time".AssertEquals(UpperDateTime);
    this.Assert.IsTrue(EntriesPage.Next(), 'The entry inside the range must match.');
    EntriesPage."Date Time".AssertEquals(MiddleDateTime);
    this.Assert.IsTrue(EntriesPage.Next(), 'The inclusive lower boundary must match.');
    EntriesPage."Date Time".AssertEquals(LowerDateTime);
    this.Assert.IsFalse(EntriesPage.Next(), 'Both entries outside the range must be excluded.');
    EntriesPage.Close();
  end;

  local procedure CreatePageProposal(var VendorProposal: Record "AMC Vendor Proposal")
  var
    TestLibrary: Codeunit "AMC Test Library";
  begin
    VendorProposal.Init();
    VendorProposal."No." := TestLibrary.NewCode();
    VendorProposal."Vendor No." := TestLibrary.NewCode();
    VendorProposal."Idempotency Key" := TestLibrary.NewCode();
    VendorProposal.Insert(true);
  end;

  local procedure LogPageEntry(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; EntryType: Enum "AMC Collab Entry Type"; Description: Text[250]; CorrelationId: Guid)
  var
    CollabLog: Codeunit "AMC Collab Log";
  begin
    if EntryType = "AMC Collab Entry Type"::Comment then
      CollabLog.LogComment(SourceType, SourceNo, 0, "AMC Actor Type"::System, '', '', Description, CorrelationId)
    else
      CollabLog.LogEvent(SourceType, SourceNo, 0, EntryType, "AMC Actor Type"::System, '', '', Description, CorrelationId);
  end;

  local procedure InsertDatedEntry(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; EntryType: Enum "AMC Collab Entry Type"; EntryDateTime: DateTime)
  var
    CollaborationEntry: Record "AMC Collaboration Entry";
  begin
    // Timeline ordering is page behavior; create immutable fixtures at their final times.
    CollaborationEntry.Init();
    CollaborationEntry."Source Type" := SourceType;
    CollaborationEntry."Source No." := SourceNo;
    CollaborationEntry."Entry Type" := EntryType;
    CollaborationEntry."Actor Type" := "AMC Actor Type"::System;
    CollaborationEntry."Date Time" := EntryDateTime;
    CollaborationEntry."Correlation Id" := CreateGuid();
    CollaborationEntry.Insert(true);
  end;

    local procedure LogEntry(EntryType: Enum "AMC Collab Entry Type"): BigInteger
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        CollabLog: Codeunit "AMC Collab Log";
        RequestNo: Code[20];
    begin
        RequestNo := this.CreateRequestNo();
        CollabLog.LogComment("AMC Source Type"::Request, RequestNo, 0, "AMC Actor Type"::Buyer, '', UserId(), 'Vendor-facing comment.', CreateGuid());
        CollabLog.LogEvent("AMC Source Type"::Request, RequestNo, 0, "AMC Collab Entry Type"::RequestCreated, "AMC Actor Type"::System, '', '', 'Vendor request created.', CreateGuid());
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", RequestNo);
        CollaborationEntry.SetRange("Entry Type", EntryType);
        CollaborationEntry.FindFirst();
        exit(CollaborationEntry."Entry No.");
    end;

    local procedure CreateRequestNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;
}
