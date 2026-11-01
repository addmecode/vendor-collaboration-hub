namespace Addmecode.VendorCollaborationHub;

table 50102 "AMC Vendor Request Line"
{
    Caption = 'Vendor Request Line';
    DataClassification = CustomerContent;
    Permissions = tabledata "AMC Vendor Request Line" = r;

    fields
    {
        field(1; "Request No."; Code[20])
        {
            AllowInCustomizations = Never;
            Caption = 'Request No.';
            ToolTip = 'Specifies the vendor request that contains this snapshot line.';
            TableRelation = "AMC Vendor Request";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            ToolTip = 'Specifies the request line number.';
        }
        field(3; "Purchase Line No."; Integer)
        {
            Caption = 'Purchase Line No.';
            ToolTip = 'Specifies the source purchase order line number.';
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            ToolTip = 'Specifies the item requested from the vendor.';
        }
        field(5; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            ToolTip = 'Specifies the item variant requested from the vendor.';
        }
        field(6; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the item description copied from the purchase order.';
        }
        field(7; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            ToolTip = 'Specifies the location where the item is requested.';
        }
        field(8; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            ToolTip = 'Specifies the unit of measure requested from the vendor.';
        }
        field(9; "Requested Quantity"; Decimal)
        {
            Caption = 'Requested Quantity';
            ToolTip = 'Specifies the quantity requested from the vendor.';
        }
        field(10; "Requested Delivery Date"; Date)
        {
            Caption = 'Requested Delivery Date';
            ToolTip = 'Specifies the requested delivery date.';
        }
        field(11; "Confirmed Quantity"; Decimal)
        {
            Caption = 'Confirmed Quantity';
            ToolTip = 'Specifies the quantity confirmed through applied proposals.';
        }
        field(12; "Outstanding Quantity"; Decimal)
        {
            Caption = 'Outstanding Quantity';
            ToolTip = 'Specifies the quantity that remains outstanding.';
        }
        field(13; Status; Enum "AMC Request Line Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the current status of the request line.';
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
