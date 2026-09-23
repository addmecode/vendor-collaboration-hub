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
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor request number.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor that receives this request.';
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the vendor that receives this request.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase order captured by this request.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the current status of the vendor request.';
                }
                field("Response Deadline"; Rec."Response Deadline")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date by which the vendor should respond.';
                }
                field("Open Proposal Count"; Rec."Open Proposal Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of proposals awaiting review for this request.';
                }
                field("Line Count"; Rec."Line Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of lines in this request.';
                }
            }
        }
    }
}
