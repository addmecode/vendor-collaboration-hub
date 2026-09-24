namespace Addmecode.VendorCollaborationHub;

table 50102 "AMC Vendor Request Line"
{
    Caption = 'Vendor Request Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            DataClassification = CustomerContent;
            TableRelation = "AMC Vendor Request";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Purchase Line No."; Integer)
        {
            Caption = 'Purchase Line No.';
            DataClassification = CustomerContent;
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
        }
        field(5; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            DataClassification = CustomerContent;
        }
        field(6; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(7; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            DataClassification = CustomerContent;
        }
        field(8; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            DataClassification = CustomerContent;
        }
        field(9; "Requested Quantity"; Decimal)
        {
            Caption = 'Requested Quantity';
            DataClassification = CustomerContent;
        }
        field(10; "Requested Delivery Date"; Date)
        {
            Caption = 'Requested Delivery Date';
            DataClassification = CustomerContent;
        }
        field(11; "Confirmed Quantity"; Decimal)
        {
            Caption = 'Confirmed Quantity';
            DataClassification = CustomerContent;
        }
        field(12; "Outstanding Quantity"; Decimal)
        {
            Caption = 'Outstanding Quantity';
            DataClassification = CustomerContent;
        }
        field(13; Status; Enum "AMC Request Line Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Request No.", "Line No.")
        {
            Clustered = true;
        }
        key(RequestPurchaseLine; "Request No.", "Purchase Line No.")
        {
            Unique = true;
        }
        key(Status; Status)
        {
        }
    }

    trigger OnModify()
    var
        PersistedVendorRequestLine: Record "AMC Vendor Request Line";
        RequestLineSnapshotCannotBeChangedErr: Label 'Vendor request line snapshot fields cannot be changed.';
    begin
        //todo: is this check needed?
        if PersistedVendorRequestLine.Get(this."Request No.", this."Line No.") and
           ((this."Purchase Line No." <> PersistedVendorRequestLine."Purchase Line No.") or
            (this."Item No." <> PersistedVendorRequestLine."Item No.") or
            (this."Variant Code" <> PersistedVendorRequestLine."Variant Code") or
            (this.Description <> PersistedVendorRequestLine.Description) or
            (this."Location Code" <> PersistedVendorRequestLine."Location Code") or
            (this."Unit of Measure Code" <> PersistedVendorRequestLine."Unit of Measure Code") or
            (this."Requested Quantity" <> PersistedVendorRequestLine."Requested Quantity") or
            (this."Requested Delivery Date" <> PersistedVendorRequestLine."Requested Delivery Date")) then
            Error(RequestLineSnapshotCannotBeChangedErr);
    end;
}
