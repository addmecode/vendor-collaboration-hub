namespace Addmecode.VendorCollaborationHub;

table 50105 "AMC Collaboration Entry"
{
    Caption = 'Collaboration Entry';
    DataClassification = CustomerContent;
    DrillDownPageId = "AMC Collaboration Entries";
    LookupPageId = "AMC Collaboration Entries";

    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            AutoIncrement = true;
            Caption = 'Entry No.';
            ToolTip = 'Specifies the unique number of this collaboration entry.';
        }
        field(2; "Source Type"; Enum "AMC Source Type")
        {
            Caption = 'Source Type';
            ToolTip = 'Specifies whether this entry belongs to a request or a proposal.';
        }
        field(3; "Source No."; Code[20])
        {
            Caption = 'Source No.';
            ToolTip = 'Specifies the request or proposal number for this entry.';
        }
        field(4; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            ToolTip = 'Specifies the related source line, if any.';
        }
        field(5; "Entry Type"; Enum "AMC Collab Entry Type")
        {
            Caption = 'Entry Type';
            ToolTip = 'Specifies the process event or comment recorded by this entry.';
        }
        field(6; "Actor Type"; Enum "AMC Actor Type")
        {
            Caption = 'Actor Type';
            ToolTip = 'Specifies who performed the action.';
        }
        field(7; "Actor Name"; Text[100])
        {
            Caption = 'Actor Name';
            ToolTip = 'Specifies the actor name recorded for this entry.';
        }
        field(8; "User ID"; Code[50])
        {
            Caption = 'User ID';
            ToolTip = 'Specifies the Business Central user recorded for this entry.';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(10; "Field Name"; Text[80])
        {
            Caption = 'Field Name';
            ToolTip = 'Specifies the changed field, if any.';
        }
        field(11; "Old Value"; Text[250])
        {
            Caption = 'Old Value';
            ToolTip = 'Specifies the value before the change, if any.';
        }
        field(12; "New Value"; Text[250])
        {
            Caption = 'New Value';
            ToolTip = 'Specifies the value after the change, if any.';
        }
        field(13; Description; Text[250])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the comment or context recorded for this entry.';
        }
        field(14; "Correlation Id"; Guid)
        {
            Caption = 'Correlation Id';
            ToolTip = 'Specifies the identifier that correlates this entry with telemetry.';
        }
        field(15; "Date Time"; DateTime)
        {
            Caption = 'Date Time';
            ToolTip = 'Specifies when this entry was recorded.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(SourceTimeline; "Source Type", "Source No.", "Date Time")
        {
        }
        key(EntryTimeline; "Entry Type", "Date Time")
        {
        }
        key(SourceComments; "Source Type", "Source No.", "Entry Type")
        {
        }
    }

    trigger OnModify()
    begin
        Error(this.EntryCannotBeModifiedErr);
    end;

    trigger OnDelete()
    begin
        Error(this.EntryCannotBeDeletedErr);
    end;

    trigger OnRename()
    begin
        Error(this.EntryCannotBeRenamedErr);
    end;

    var
        EntryCannotBeModifiedErr: Label 'Collaboration entries cannot be modified.';
        EntryCannotBeDeletedErr: Label 'Collaboration entries cannot be deleted.';
        EntryCannotBeRenamedErr: Label 'Collaboration entries cannot be renamed.';
}
