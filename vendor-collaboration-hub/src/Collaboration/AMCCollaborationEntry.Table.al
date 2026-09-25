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
            DataClassification = CustomerContent;
        }
        field(2; "Source Type"; Enum "AMC Source Type")
        {
            Caption = 'Source Type';
            DataClassification = CustomerContent;
        }
        field(3; "Source No."; Code[20])
        {
            Caption = 'Source No.';
            DataClassification = CustomerContent;
        }
        field(4; "Source Line No."; Integer)
        {
            Caption = 'Source Line No.';
            DataClassification = CustomerContent;
        }
        field(5; "Entry Type"; Enum "AMC Collab Entry Type")
        {
            Caption = 'Entry Type';
            DataClassification = CustomerContent;
        }
        field(6; "Actor Type"; Enum "AMC Actor Type")
        {
            Caption = 'Actor Type';
            DataClassification = CustomerContent;
        }
        field(7; "Actor Name"; Text[100])
        {
            Caption = 'Actor Name';
            DataClassification = CustomerContent;
        }
        field(8; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(9; "Visible to Vendor"; Boolean)
        {
            Caption = 'Visible to Vendor';
            DataClassification = CustomerContent;
        }
        field(10; "Field Name"; Text[80])
        {
            Caption = 'Field Name';
            DataClassification = CustomerContent;
        }
        field(11; "Old Value"; Text[250])
        {
            Caption = 'Old Value';
            DataClassification = CustomerContent;
        }
        field(12; "New Value"; Text[250])
        {
            Caption = 'New Value';
            DataClassification = CustomerContent;
        }
        field(13; Description; Text[250])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(14; "Correlation Id"; Guid)
        {
            Caption = 'Correlation Id';
            DataClassification = CustomerContent;
        }
        field(15; "Date Time"; DateTime)
        {
            Caption = 'Date Time';
            DataClassification = CustomerContent;
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
        key(VendorTimeline; "Source Type", "Source No.", "Visible to Vendor")
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
