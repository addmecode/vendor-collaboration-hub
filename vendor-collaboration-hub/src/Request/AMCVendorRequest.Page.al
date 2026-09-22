namespace Addmecode.VendorCollaborationHub;

page 50103 "AMC Vendor Request"
{
    ApplicationArea = All;
    Caption = 'Vendor Request';
    PageType = Document;
    SourceTable = "AMC Vendor Request";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

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
                field("Purchaser Code"; Rec."Purchaser Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchaser responsible for this request.';
                }
                field("Assigned User ID"; Rec."Assigned User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user assigned to this request.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency copied from the purchase order.';
                }
                field("Language Code"; Rec."Language Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the language used when communicating with the vendor.';
                }
                field("External Reference"; Rec."External Reference")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor reference for this request.';
                }
            }
            group(Dates)
            {
                Caption = 'Dates';

                field("Sent Date Time"; Rec."Sent Date Time")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when this request was sent to the vendor.';
                }
                field("Response Deadline"; Rec."Response Deadline")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date by which the vendor should respond.';
                }
                field("Closed Date Time"; Rec."Closed Date Time")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when this request was closed.';
                }
            }
            part(RequestLines; "AMC Vendor Request Subform")
            {
                ApplicationArea = All;
                Caption = 'Lines';
                SubPageLink = "Request No." = field("No.");
                UpdatePropagation = Both;
            }
            group(Statistics)
            {
                Caption = 'Statistics';

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
