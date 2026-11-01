namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.AuditCodes;
using Microsoft.Inventory.Item;

table 50104 "AMC Vendor Proposal Line"
{
    Caption = 'Vendor Proposal Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Proposal No."; Code[20])
        {
            AllowInCustomizations = Never;
            Caption = 'Proposal No.';
            ToolTip = 'Specifies the vendor proposal that contains this line.';
            TableRelation = "AMC Vendor Proposal";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            ToolTip = 'Specifies the vendor proposal line number.';
        }
        field(3; "Request Line No."; Integer)
        {
            Caption = 'Request Line No.';
            ToolTip = 'Specifies the request line answered by this proposal line.';
        }
        field(4; "Line Type"; Enum "AMC Proposal Line Type")
        {
            Caption = 'Line Type';
            ToolTip = 'Specifies the type of fulfillment proposed for the request line.';
        }
        field(5; "Sequence No."; Integer)
        {
            Caption = 'Sequence No.';
            ToolTip = 'Specifies the order of this fulfillment proposal for its request line.';
        }
        field(6; "Proposed Item No."; Code[20])
        {
            Caption = 'Proposed Item No.';
            ToolTip = 'Specifies the item proposed as a substitute.';
            TableRelation = Item;
        }
        field(7; "Proposed Variant Code"; Code[10])
        {
            Caption = 'Proposed Variant Code';
            ToolTip = 'Specifies the variant of the proposed substitute item.';
            TableRelation = "Item Variant".Code where("Item No." = field("Proposed Item No."));
        }
        field(8; "Proposed Quantity"; Decimal)
        {
            Caption = 'Proposed Quantity';
            ToolTip = 'Specifies the quantity proposed for this fulfillment.';
        }
        field(9; "Proposed Delivery Date"; Date)
        {
            Caption = 'Proposed Delivery Date';
            ToolTip = 'Specifies the delivery date proposed for this fulfillment.';
        }
        field(10; "Reason Code"; Code[10])
        {
            Caption = 'Reason Code';
            ToolTip = 'Specifies the code for the reason for this proposal line.';
            TableRelation = "Reason Code";
        }
        field(11; "Reason Description"; Text[250])
        {
            Caption = 'Reason Description';
            ToolTip = 'Specifies the vendor description of the reason for this proposal line.';
        }
        field(12; Applied; Boolean)
        {
            Caption = 'Applied';
            ToolTip = 'Specifies whether this proposal line has been applied to the purchase order.';
        }
        field(13; "Applied Purchase Line No."; Integer)
        {
            Caption = 'Applied Purchase Line No.';
            ToolTip = 'Specifies the purchase order line created or changed by this proposal line.';
        }
    }

    keys
    {
        key(PK; "Proposal No.", "Line No.")
        {
            Clustered = true;
        }
        key(ProposalRequestLineSequence; "Proposal No.", "Request Line No.", "Sequence No.")
        {
        }
        key(ProposalSequence; "Proposal No.", "Sequence No.", "Line No.")
        {
        }
    }
}
