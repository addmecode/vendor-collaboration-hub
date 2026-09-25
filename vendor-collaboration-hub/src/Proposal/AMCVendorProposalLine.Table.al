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
            Caption = 'Proposal No.';
            DataClassification = CustomerContent;
            TableRelation = "AMC Vendor Proposal";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = CustomerContent;
        }
        field(3; "Request Line No."; Integer)
        {
            Caption = 'Request Line No.';
            DataClassification = CustomerContent;
        }
        field(4; "Line Type"; Enum "AMC Proposal Line Type")
        {
            Caption = 'Line Type';
            DataClassification = CustomerContent;
        }
        field(5; "Sequence No."; Integer)
        {
            Caption = 'Sequence No.';
            DataClassification = CustomerContent;
        }
        field(6; "Proposed Item No."; Code[20])
        {
            Caption = 'Proposed Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
        }
        field(7; "Proposed Variant Code"; Code[10])
        {
            Caption = 'Proposed Variant Code';
            DataClassification = CustomerContent;
            TableRelation = "Item Variant".Code where("Item No." = field("Proposed Item No."));
        }
        field(8; "Proposed Quantity"; Decimal)
        {
            Caption = 'Proposed Quantity';
            DataClassification = CustomerContent;
        }
        field(9; "Proposed Delivery Date"; Date)
        {
            Caption = 'Proposed Delivery Date';
            DataClassification = CustomerContent;
        }
        field(10; "Reason Code"; Code[10])
        {
            Caption = 'Reason Code';
            DataClassification = CustomerContent;
            TableRelation = "Reason Code";
        }
        field(11; "Reason Description"; Text[250])
        {
            Caption = 'Reason Description';
            DataClassification = CustomerContent;
        }
        field(12; Applied; Boolean)
        {
            Caption = 'Applied';
            DataClassification = CustomerContent;
        }
        field(13; "Applied Purchase Line No."; Integer)
        {
            Caption = 'Applied Purchase Line No.';
            DataClassification = CustomerContent;
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
    }
}
