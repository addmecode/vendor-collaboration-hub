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
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor proposal line number.';
                }
                field("Request Line No."; Rec."Request Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the request line answered by this proposal line.';
                }
                field("Line Type"; Rec."Line Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the type of fulfillment proposed for the request line.';
                }
                field("Sequence No."; Rec."Sequence No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the order of this fulfillment proposal for its request line.';
                }
                field("Proposed Item No."; Rec."Proposed Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item proposed as a substitute.';
                }
                field("Proposed Variant Code"; Rec."Proposed Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant of the proposed substitute item.';
                }
                field("Proposed Quantity"; Rec."Proposed Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity proposed for this fulfillment.';
                }
                field("Proposed Delivery Date"; Rec."Proposed Delivery Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the delivery date proposed for this fulfillment.';
                }
                field("Reason Code"; Rec."Reason Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the code for the reason for this proposal line.';
                }
                field("Reason Description"; Rec."Reason Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor description of the reason for this proposal line.';
                }
                field(Applied; Rec.Applied)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies whether this proposal line has been applied to the purchase order.';
                }
                field("Applied Purchase Line No."; Rec."Applied Purchase Line No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the purchase order line created or changed by this proposal line.';
                }
            }
        }
    }
}
