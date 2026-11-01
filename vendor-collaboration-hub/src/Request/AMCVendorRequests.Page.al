namespace Addmecode.VendorCollaborationHub;

page 50102 "AMC Vendor Requests"
{
    ApplicationArea = All;
    Caption = 'Vendor Requests';
    CardPageId = "AMC Vendor Request";
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "AMC Vendor Request";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                }
                field(Status; Rec.Status)
                {
                    Editable = false;
                }
                field("Response Deadline"; Rec."Response Deadline")
                {
                }
                field("Open Proposal Count"; Rec."Open Proposal Count")
                {
                }
                field("Line Count"; Rec."Line Count")
                {
                }
            }
        }
    }
}
