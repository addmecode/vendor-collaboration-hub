namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Appends collaboration events, comments and field changes and validates vendor comment ownership.
/// </summary>
codeunit 50105 "AMC Collab Log"
{
    Permissions = tabledata "AMC Collaboration Entry" = ri,
                  tabledata "AMC Vendor Access Token" = r,
                  tabledata "AMC Vendor Proposal" = r;

    /// <summary>
    /// Appends a timestamped collaboration event without field-change values.
    /// </summary>
    /// <param name="SourceType">The request or proposal source type.</param>
    /// <param name="SourceNo">The source document number.</param>
    /// <param name="SourceLineNo">The source line number, or zero for a document event.</param>
    /// <param name="EntryType">The event classification.</param>
    /// <param name="ActorType">The buyer, vendor or system actor category.</param>
    /// <param name="ActorName">The actor's display name.</param>
    /// <param name="UserId">The recorded BC user identity, when applicable.</param>
    /// <param name="Description">The event description; must not contain bearer tokens.</param>
    /// <param name="CorrelationId">The identifier linking related operations.</param>
    procedure LogEvent(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; Description: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, EntryType, ActorType, ActorName, UserId, '', '', '', Description, CorrelationId);
    end;

    /// <summary>
    /// Appends a timestamped comment from trusted application code; vendor API callers use WriteVendorComment for authorization.
    /// </summary>
    /// <param name="SourceType">The request or proposal source type.</param>
    /// <param name="SourceNo">The source document number.</param>
    /// <param name="SourceLineNo">The source line number, or zero for a document comment.</param>
    /// <param name="ActorType">The actor category to record.</param>
    /// <param name="ActorName">The actor's display name.</param>
    /// <param name="UserId">The recorded BC user identity, when applicable.</param>
    /// <param name="Comment">The comment text; must not contain bearer tokens.</param>
    /// <param name="CorrelationId">The identifier linking related operations.</param>
    procedure LogComment(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; Comment: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, "AMC Collab Entry Type"::Comment, ActorType, ActorName, UserId, '', '', '', Comment, CorrelationId);
    end;

    /// <summary>
    /// Appends a timestamped audit entry with the changed field's old and new display values.
    /// </summary>
    /// <param name="SourceType">The request or proposal source type.</param>
    /// <param name="SourceNo">The source document number.</param>
    /// <param name="SourceLineNo">The affected source line number.</param>
    /// <param name="EntryType">The event classification.</param>
    /// <param name="ActorType">The actor category to record.</param>
    /// <param name="ActorName">The actor's display name.</param>
    /// <param name="UserId">The recorded BC user identity, when applicable.</param>
    /// <param name="FieldName">The changed field name.</param>
    /// <param name="OldValue">The previous field value.</param>
    /// <param name="NewValue">The resulting field value.</param>
    /// <param name="Description">The change description; must not contain bearer tokens.</param>
    /// <param name="CorrelationId">The identifier linking related operations.</param>
    procedure LogFieldChange(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250]; Description: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, EntryType, ActorType, ActorName, UserId, FieldName, OldValue, NewValue, Description, CorrelationId);
    end;

  /// <summary>
  /// Validates token and source ownership and request openness, then inserts a document-level vendor comment without committing.
  /// </summary>
  /// <param name="CollaborationEntry">Supplies source, actor name, text and optional correlation; receives the persisted vendor comment.</param>
  /// <param name="AccessTokenId">The access token's API SystemId used to authorize the write.</param>
  [CommitBehavior(CommitBehavior::Error)]
  procedure WriteVendorComment(var CollaborationEntry: Record "AMC Collaboration Entry"; AccessTokenId: Guid)
  var
    VendorAccessToken: Record "AMC Vendor Access Token";
    VendorRequest: Record "AMC Vendor Request";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    EntryId: Guid;
    TokenInvalidErr: Label 'VCH-AUT-0003: This access link is no longer valid.';
    EntryNotFoundErr: Label 'VCH-DAT-0001: The comment entry could not be read after it was created.';
  begin
    if (CollaborationEntry.Description = '') or
       not (CollaborationEntry."Source Type" in ["AMC Source Type"::Request, "AMC Source Type"::Proposal]) then
      Error(this.CommentInvalidErr);
    VendorAccessToken.SetLoadFields("Request No.", "Vendor No.");
    if not VendorAccessToken.GetBySystemId(AccessTokenId) then
      Error(TokenInvalidErr);
    this.VerifyCommentSource(CollaborationEntry, VendorAccessToken);
    ProposalMgt.AssertApiIdentity(AccessTokenId, VendorAccessToken."Request No.", VendorAccessToken."Vendor No.");
    ProposalMgt.AssertApiRequest(VendorAccessToken."Request No.", VendorAccessToken."Vendor No.", VendorRequest);
    if IsNullGuid(CollaborationEntry."Correlation Id") then
      CollaborationEntry.Validate("Correlation Id", CreateGuid());
    EntryId := this.InsertEntry(CollaborationEntry."Source Type", CollaborationEntry."Source No.", 0,
      "AMC Collab Entry Type"::Comment, "AMC Actor Type"::Vendor, CollaborationEntry."Actor Name", '',
      '', '', '', CollaborationEntry.Description, CollaborationEntry."Correlation Id");
    if not CollaborationEntry.GetBySystemId(EntryId) then
      Error(EntryNotFoundErr);
  end;

  local procedure VerifyCommentSource(CollaborationEntry: Record "AMC Collaboration Entry"; VendorAccessToken: Record "AMC Vendor Access Token")
  begin
    case CollaborationEntry."Source Type" of
      "AMC Source Type"::Request:
        if CollaborationEntry."Source No." <> VendorAccessToken."Request No." then
          Error(this.SourceMismatchErr);
      "AMC Source Type"::Proposal:
        this.VerifyProposalCommentSource(CollaborationEntry."Source No.", VendorAccessToken);
    end;
  end;

  local procedure VerifyProposalCommentSource(ProposalNo: Code[20]; VendorAccessToken: Record "AMC Vendor Access Token")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    VendorProposal.SetLoadFields("Request No.", "Vendor No.", "API Submission Pending");
    if not VendorProposal.Get(ProposalNo) then
      Error(this.CommentInvalidErr);
    if (VendorProposal."Request No." <> VendorAccessToken."Request No.") or
       (VendorProposal."Vendor No." <> VendorAccessToken."Vendor No.") or VendorProposal."API Submission Pending" then
      Error(this.SourceMismatchErr);
  end;

    local procedure InsertEntry(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250]; Description: Text[250]; CorrelationId: Guid): Guid
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
    begin
        CollaborationEntry.Init();
        CollaborationEntry.Validate("Source Type", SourceType);
        CollaborationEntry.Validate("Source No.", SourceNo);
        CollaborationEntry.Validate("Source Line No.", SourceLineNo);
        CollaborationEntry.Validate("Entry Type", EntryType);
        CollaborationEntry.Validate("Actor Type", ActorType);
        CollaborationEntry.Validate("Actor Name", ActorName);
        CollaborationEntry.Validate("User ID", UserId);
        CollaborationEntry.Validate("Field Name", FieldName);
        CollaborationEntry.Validate("Old Value", OldValue);
        CollaborationEntry.Validate("New Value", NewValue);
        CollaborationEntry.Validate(Description, Description);
        CollaborationEntry.Validate("Correlation Id", CorrelationId);
        CollaborationEntry.Validate("Date Time", CurrentDateTime());
        CollaborationEntry.Insert(false);
        exit(CollaborationEntry.SystemId);
    end;

    var
        SourceMismatchErr: Label 'VCH-AUT-0004: The comment source does not belong to the access link request and vendor.';
        CommentInvalidErr: Label 'VCH-VAL-0001: A comment requires an existing Request or Proposal source and non-empty text.';
}
