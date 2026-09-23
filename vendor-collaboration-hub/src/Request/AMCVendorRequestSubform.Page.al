namespace Addmecode.VendorCollaborationHub;

page 50104 "AMC Vendor Request Subform"
{
    ApplicationArea = All;
    AutoSplitKey = true;
    Caption = 'Vendor Request Lines';
    DelayedInsert = true;
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = ListPart;
    SourceTable = "AMC Vendor Request Line";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the request line number.';
                }
                field("Purchase Line No."; Rec."Purchase Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source purchase order line number.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item requested from the vendor.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item variant requested from the vendor.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item description copied from the purchase order.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location where the item is requested.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure requested from the vendor.';
                }
                field("Requested Quantity"; Rec."Requested Quantity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity requested from the vendor.';
                }
                field("Requested Delivery Date"; Rec."Requested Delivery Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the requested delivery date.';
                }
                field("Confirmed Quantity"; Rec."Confirmed Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the quantity confirmed through applied proposals.';
                }
                field("Outstanding Quantity"; Rec."Outstanding Quantity")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the quantity that remains outstanding.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the current status of the request line.';
                }
            }
        }
    }
}
