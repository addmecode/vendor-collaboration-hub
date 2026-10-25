namespace Addmecode.VendorCollaborationHub;

table 50105 "AMC Collaboration Entry"
{
    Caption = 'Collaboration Entry';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            AutoIncrement = true;
            Caption = 'Entry No.';
        }
        field(2; "Source Type"; Enum "AMC Source Type")
        {
            Caption = 'Source Type';
        }
        field(3; "Source No."; Code[20])
        {
            Caption = 'Source No.';
        }
        field(4; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
        }
        field(5; "Entry Type"; Enum "AMC Collab Entry Type")
        {
            Caption = 'Entry Type';
        }
        field(6; "Actor Type"; Enum "AMC Actor Type")
        {
            Caption = 'Actor Type';
        }
        field(7; "Actor Name"; Text[100])
        {
            Caption = 'Actor Name';
        }
        field(8; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(10; "Field Name"; Text[80])
        {
            Caption = 'Field Name';
        }
        field(11; "Old Value"; Text[250])
        {
            Caption = 'Old Value';
        }
        field(12; "New Value"; Text[250])
        {
            Caption = 'New Value';
        }
        field(13; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(14; "Correlation Id"; Guid)
        {
            Caption = 'Correlation Id';
        }
        field(15; "Date Time"; DateTime)
        {
            Caption = 'Date Time';
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
