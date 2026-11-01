namespace Addmecode.VendorCollaborationHub;

page 50108 "AMC Vendor Proposal Subform"
{
    ApplicationArea = All;
    AutoSplitKey = true;
    Caption = 'Vendor Proposal Lines';
    DelayedInsert = true;
    DeleteAllowed = false;
    PageType = ListPart;
    SourceTable = "AMC Vendor Proposal Line";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Line No."; Rec."Line No.")
                {
                }
                field("Request Line No."; Rec."Request Line No.")
                {
                }
                field("Line Type"; Rec."Line Type")
                {
                }
                field("Sequence No."; Rec."Sequence No.")
                {
                }
                field("Proposed Item No."; Rec."Proposed Item No.")
                {
                }
                field("Proposed Variant Code"; Rec."Proposed Variant Code")
                {
                }
                field("Proposed Quantity"; Rec."Proposed Quantity")
                {
                }
                field("Proposed Delivery Date"; Rec."Proposed Delivery Date")
                {
                }
                field("Reason Code"; Rec."Reason Code")
                {
                }
                field("Reason Description"; Rec."Reason Description")
                {
                }
                field(Applied; Rec.Applied)
                {
                    Editable = false;
                }
                field("Applied Purchase Line No."; Rec."Applied Purchase Line No.")
                {
                    Editable = false;
                }
            }
        }
    }
}
