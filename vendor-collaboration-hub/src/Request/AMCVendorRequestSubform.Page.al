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
                }
                field("Purchase Line No."; Rec."Purchase Line No.")
                {
                }
                field("Item No."; Rec."Item No.")
                {
                }
                field("Variant Code"; Rec."Variant Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Location Code"; Rec."Location Code")
                {
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                }
                field("Requested Quantity"; Rec."Requested Quantity")
                {
                }
                field("Requested Delivery Date"; Rec."Requested Delivery Date")
                {
                }
                field("Confirmed Quantity"; Rec."Confirmed Quantity")
                {
                    Editable = false;
                }
                field("Outstanding Quantity"; Rec."Outstanding Quantity")
                {
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    Editable = false;
                }
            }
        }
    }
}
