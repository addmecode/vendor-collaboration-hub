namespace Addmecode.VendorCollaborationHub;

codeunit 50105 "AMC Collab Log"
{
    Permissions = tabledata "AMC Collaboration Entry" = ri,
                  tabledata "AMC Vendor Access Token" = r,
                  tabledata "AMC Vendor Proposal" = r;

    procedure LogEvent(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; Description: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, EntryType, ActorType, ActorName, UserId, '', '', '', Description, CorrelationId);
    end;

    procedure LogComment(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; Comment: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, "AMC Collab Entry Type"::Comment, ActorType, ActorName, UserId, '', '', '', Comment, CorrelationId);
    end;

    procedure LogFieldChange(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250]; Description: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, EntryType, ActorType, ActorName, UserId, FieldName, OldValue, NewValue, Description, CorrelationId);
    end;

  [CommitBehavior(CommitBehavior::Error)]
  procedure WriteVendorComment(var CollaborationEntry: Record "AMC Collaboration Entry"; AccessTokenId: Guid)
  var
    VendorAccessToken: Record "AMC Vendor Access Token";
    VendorProposal: Record "AMC Vendor Proposal";
    VendorRequest: Record "AMC Vendor Request";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    EntryId: Guid;
    TokenInvalidErr: Label 'VCH-AUT-0003: This access link is no longer valid.';
    SourceMismatchErr: Label 'VCH-AUT-0004: The comment source does not belong to the access link request and vendor.';
    CommentInvalidErr: Label 'VCH-VAL-0001: A comment requires an existing Request or Proposal source and non-empty text.';
  begin
    if (CollaborationEntry.Description = '') or
       not (CollaborationEntry."Source Type" in ["AMC Source Type"::Request, "AMC Source Type"::Proposal]) then
      Error(CommentInvalidErr);
    VendorAccessToken.SetLoadFields("Request No.", "Vendor No.");
    if not VendorAccessToken.GetBySystemId(AccessTokenId) then
      Error(TokenInvalidErr);
    case CollaborationEntry."Source Type" of
      "AMC Source Type"::Request:
        if CollaborationEntry."Source No." <> VendorAccessToken."Request No." then
          Error(SourceMismatchErr);
      "AMC Source Type"::Proposal:
        begin
          VendorProposal.SetLoadFields("Request No.", "Vendor No.", "API Submission Pending");
          if not VendorProposal.Get(CollaborationEntry."Source No.") then
            Error(CommentInvalidErr);
          if (VendorProposal."Request No." <> VendorAccessToken."Request No.") or
             (VendorProposal."Vendor No." <> VendorAccessToken."Vendor No.") or VendorProposal."API Submission Pending" then
            Error(SourceMismatchErr);
        end;
    end;
    ProposalMgt.AssertApiIdentity(AccessTokenId, VendorAccessToken."Request No.", VendorAccessToken."Vendor No.");
    ProposalMgt.AssertApiRequest(VendorAccessToken."Request No.", VendorAccessToken."Vendor No.", VendorRequest);
    if IsNullGuid(CollaborationEntry."Correlation Id") then
      CollaborationEntry."Correlation Id" := CreateGuid();
    EntryId := this.InsertEntry(CollaborationEntry."Source Type", CollaborationEntry."Source No.", 0,
      "AMC Collab Entry Type"::Comment, "AMC Actor Type"::Vendor, CollaborationEntry."Actor Name", '',
      '', '', '', CollaborationEntry.Description, CollaborationEntry."Correlation Id");
    CollaborationEntry.GetBySystemId(EntryId);
  end;

    local procedure InsertEntry(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250]; Description: Text[250]; CorrelationId: Guid): Guid
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
    begin
        CollaborationEntry.Init();
        CollaborationEntry."Source Type" := SourceType;
        CollaborationEntry."Source No." := SourceNo;
        CollaborationEntry."Source Line No." := SourceLineNo;
        CollaborationEntry."Entry Type" := EntryType;
        CollaborationEntry."Actor Type" := ActorType;
        CollaborationEntry."Actor Name" := ActorName;
        CollaborationEntry."User ID" := UserId;
        CollaborationEntry."Field Name" := FieldName;
        CollaborationEntry."Old Value" := OldValue;
        CollaborationEntry."New Value" := NewValue;
        CollaborationEntry.Description := Description;
        CollaborationEntry."Correlation Id" := CorrelationId;
        CollaborationEntry."Date Time" := CurrentDateTime();
        CollaborationEntry.Insert(false);
        exit(CollaborationEntry.SystemId);
    end;
}
