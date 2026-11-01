namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.TestLibraries.Utilities;

codeunit 50148 "AMC Comment API Tests"
{
  Subtype = Test;
  Permissions = tabledata "AMC Collaboration Entry" = r,
                tabledata "AMC Vendor Access Token" = m,
                tabledata "AMC Vendor Proposal" = m,
                tabledata "AMC Vendor Request" = m;

  [Test]
  procedure GivenRequestComment_WhenWriting_ThenCommentTypeAndVendorAuditFieldsAreForced()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Entry: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    this.InitializeComment(Entry, "AMC Source Type"::Request, VendorRequest."No.");
    Entry.Validate("Entry Type", Entry."Entry Type"::ProposalReceived);
    Entry.Validate("Actor Type", Entry."Actor Type"::Buyer);
    Entry.Validate("User ID", 'SPOOFED');
    Entry.Validate("Source Line No.", 10000);
    Entry.Validate("Field Name", 'SPOOFED');
    Entry.Validate("Old Value", 'SPOOFED');
    Entry.Validate("New Value", 'SPOOFED');
    // When
    CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    // Then
    this.Assert.AreEqual(Entry."Actor Type"::Vendor, Entry."Actor Type", 'The caller cannot impersonate a buyer.');
    this.Assert.AreEqual(Entry."Entry Type"::Comment, Entry."Entry Type", 'The endpoint can write comments only.');
    this.Assert.AreEqual('', Entry."User ID", 'The caller cannot set an internal user identity.');
    this.Assert.AreEqual('', Entry."Field Name", 'The endpoint cannot write field-change entries.');
    this.Assert.AreEqual('', Entry."Old Value", 'The endpoint cannot write old field values.');
    this.Assert.AreEqual('', Entry."New Value", 'The endpoint cannot write new field values.');
    this.Assert.AreEqual(0, Entry."Source Line No.", 'Only aggregate-level comments are supported.');
    this.Assert.IsTrue(Entry."Date Time" <> 0DT, 'The log writer stamps the comment.');
    this.Assert.IsFalse(IsNullGuid(Entry."Correlation Id"), 'The log writer supplies a missing correlation ID.');
    this.Assert.IsFalse(IsNullGuid(Entry.SystemId), 'The API returns the actual inserted entry.');
  end;

  [Test]
  procedure GivenProposalComment_WhenWritingWithPairedToken_ThenVendorCommentIsCreated()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Proposal: Record "AMC Vendor Proposal";
    Entry: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, Format(CreateGuid()), 400, false, Proposal);
    this.InitializeComment(Entry, "AMC Source Type"::Proposal, Proposal."No.");
    // When
    CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    // Then
    this.Assert.AreEqual(Proposal."No.", Entry."Source No.", 'Keep the authorized proposal source.');
    this.Assert.AreEqual('anna.k@example.com', Entry."Actor Name", 'Keep the submitted author display name.');
    this.Assert.AreEqual("AMC Collab Entry Type"::Comment, Entry."Entry Type", 'The proposal writer records a comment.');
    this.Assert.AreEqual("AMC Actor Type"::Vendor, Entry."Actor Type", 'The proposal comment is vendor-authored.');
  end;

  [Test]
  procedure GivenForeignRequestOrProposal_WhenCommenting_ThenNoEntryIsWritten()
  var
    VendorRequest: Record "AMC Vendor Request";
    ForeignRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    ForeignToken: Record "AMC Vendor Access Token";
    ForeignProposal: Record "AMC Vendor Proposal";
    Entry: Record "AMC Collaboration Entry";
    EntryView: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
    BeforeCount: Integer;
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    this.TestLibrary.CreateWriteContext(ForeignRequest, ForeignToken);
    // Expected errors roll back the current transaction; preserve the arrange baseline.
    Commit();
    this.TestLibrary.SubmitAnswer(ForeignRequest, ForeignToken.SystemId, Format(CreateGuid()), 400, false, ForeignProposal);
    Commit(); // Preserve the foreign proposal and audit baseline across both expected comment-authorization errors.
    BeforeCount := EntryView.Count();
    // When / Then
    this.InitializeComment(Entry, "AMC Source Type"::Request, ForeignRequest."No.");
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-AUT-0004');
    this.InitializeComment(Entry, "AMC Source Type"::Proposal, ForeignProposal."No.");
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-AUT-0004');
    this.Assert.AreEqual(BeforeCount, EntryView.Count(), 'Foreign-source comments must not write a timeline entry.');
    ClearLastError();
  end;

  [Test]
  procedure GivenSameVendorForeignRequest_WhenCommenting_ThenSourceIsRejected()
  var
    VendorRequest: Record "AMC Vendor Request";
    ForeignRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    ForeignToken: Record "AMC Vendor Access Token";
    ForeignProposal: Record "AMC Vendor Proposal";
    Entry: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
  begin
    // Given: matching vendor alone is not authorization for a different request.
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    this.TestLibrary.CreateWriteContext(ForeignRequest, ForeignToken);
    Commit(); // Separate the two request/token fixtures from the same-vendor ownership changes below.
    ForeignRequest.Validate("Vendor No.", VendorRequest."Vendor No.");
    ForeignRequest.Modify(false);
    ForeignToken.Validate("Vendor No.", VendorRequest."Vendor No.");
    ForeignToken.Modify(false);
    Commit(); // Establish the same-vendor, foreign-request baseline before creating its proposal.
    this.TestLibrary.SubmitAnswer(ForeignRequest, ForeignToken.SystemId, Format(CreateGuid()), 400, false, ForeignProposal);
    Commit(); // Keep the foreign-request proposal available after the expected comment-authorization rollback.
    this.InitializeComment(Entry, "AMC Source Type"::Proposal, ForeignProposal."No.");
    // When / Then
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-AUT-0004');
    ClearLastError();
  end;

  [Test]
  procedure GivenSameRequestForeignVendorProposal_WhenCommenting_ThenNoEntryIsWritten()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    ForeignProposal: Record "AMC Vendor Proposal";
    Entry: Record "AMC Collaboration Entry";
    EntryView: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
    BeforeCount: Integer;
  begin
    // Given: isolate vendor ownership while keeping the proposal's request paired to the token.
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit(); // Separate the paired request/token baseline from the deliberately foreign-vendor proposal.
    this.TestLibrary.SubmitAnswer(VendorRequest, AccessToken.SystemId, Format(CreateGuid()), 400, false, ForeignProposal);
    ForeignProposal.Validate("Vendor No.", this.TestLibrary.NewCode());
    ForeignProposal.Modify(false);
    Commit(); // Preserve the mismatched proposal and audit baseline across the expected ownership error.
    BeforeCount := EntryView.Count();
    this.InitializeComment(Entry, "AMC Source Type"::Proposal, ForeignProposal."No.");
    // When / Then
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-AUT-0004');
    this.Assert.AreEqual(BeforeCount, EntryView.Count(), 'Matching request alone must not authorize a foreign-vendor proposal comment.');
    ClearLastError();
  end;

  [Test]
  procedure GivenInvalidSourceTextOrToken_WhenCommenting_ThenNoEntryIsWritten()
  var
    VendorRequest: Record "AMC Vendor Request";
    AccessToken: Record "AMC Vendor Access Token";
    Entry: Record "AMC Collaboration Entry";
    EntryView: Record "AMC Collaboration Entry";
    CollabLog: Codeunit "AMC Collab Log";
    BeforeCount: Integer;
  begin
    // Given
    this.TestLibrary.CreateWriteContext(VendorRequest, AccessToken);
    Commit(); // Preserve request/token fixtures and the entry-count baseline across expected invalid-comment errors.
    BeforeCount := EntryView.Count();
    // When / Then
    this.InitializeComment(Entry, "AMC Source Type"::Proposal, 'MISSING');
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-VAL-0001');
    this.InitializeComment(Entry, "AMC Source Type"::Request, VendorRequest."No.");
    Entry.Validate(Description, '');
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-VAL-0001');
    this.InitializeComment(Entry, "AMC Source Type"::Request, VendorRequest."No.");
    Entry.Validate("Source Type", "AMC Source Type".FromInteger(999999));
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-VAL-0001');
    this.InitializeComment(Entry, "AMC Source Type"::Request, VendorRequest."No.");
    AccessToken.Validate(Status, AccessToken.Status::Revoked);
    AccessToken.Modify(false);
    Commit(); // Keep the token revoked when the expected token-validation error rolls back.
    asserterror CollabLog.WriteVendorComment(Entry, AccessToken.SystemId);
    this.Assert.ExpectedError('VCH-AUT-0003');
    this.Assert.AreEqual(BeforeCount, EntryView.Count(), 'Invalid comments must leave no entries.');
    ClearLastError();
  end;

  local procedure InitializeComment(var Entry: Record "AMC Collaboration Entry"; SourceType: Enum "AMC Source Type"; SourceNo: Code[20])
  begin
    Clear(Entry);
    Entry.Init();
    Entry.Validate("Source Type", SourceType);
    Entry.Validate("Source No.", SourceNo);
    Entry.Validate("Actor Name", 'anna.k@example.com');
    Entry.Validate(Description, 'We can pull 400 pcs forward.');
  end;

  var
    Assert: Codeunit "Library Assert";
    TestLibrary: Codeunit "AMC Test Library";
}
