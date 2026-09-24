namespace Addmecode.VendorCollaborationHub;

codeunit 50105 "AMC Collab Log"
{
    Permissions = tabledata "AMC Collaboration Entry" = I;

    procedure LogEvent(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; VisibleToVendor: Boolean; Description: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, EntryType, ActorType, ActorName, UserId, VisibleToVendor, '', '', '', Description, CorrelationId);
    end;

    procedure LogComment(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; VisibleToVendor: Boolean; Comment: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, "AMC Collab Entry Type"::Comment, ActorType, ActorName, UserId, VisibleToVendor, '', '', '', Comment, CorrelationId);
    end;

    procedure LogFieldChange(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; VisibleToVendor: Boolean; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250]; Description: Text[250]; CorrelationId: Guid)
    begin
        this.InsertEntry(SourceType, SourceNo, SourceLineNo, EntryType, ActorType, ActorName, UserId, VisibleToVendor, FieldName, OldValue, NewValue, Description, CorrelationId);
    end;

    local procedure InsertEntry(SourceType: Enum "AMC Source Type"; SourceNo: Code[20]; SourceLineNo: Integer; EntryType: Enum "AMC Collab Entry Type"; ActorType: Enum "AMC Actor Type"; ActorName: Text[100]; UserId: Code[50]; VisibleToVendor: Boolean; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250]; Description: Text[250]; CorrelationId: Guid)
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
        CollaborationEntry."Visible to Vendor" := VisibleToVendor;
        CollaborationEntry."Field Name" := FieldName;
        CollaborationEntry."Old Value" := OldValue;
        CollaborationEntry."New Value" := NewValue;
        CollaborationEntry.Description := Description;
        CollaborationEntry."Correlation Id" := CorrelationId;
        CollaborationEntry."Date Time" := CurrentDateTime();
        CollaborationEntry.Insert();
    end;
}
