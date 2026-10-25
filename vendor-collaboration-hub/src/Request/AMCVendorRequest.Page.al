namespace Addmecode.VendorCollaborationHub;

page 50103 "AMC Vendor Request"
{
    ApplicationArea = All;
    Caption = 'Vendor Request';
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
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
                    ToolTip = 'Specifies the vendor request number.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the vendor that receives this request.';
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ToolTip = 'Specifies the name of the vendor that receives this request.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ToolTip = 'Specifies the purchase order captured by this request.';
                }
                field(Status; Rec.Status)
                {
                    Editable = false;
                    ToolTip = 'Specifies the current status of the vendor request.';
                }
                field("Purchaser Code"; Rec."Purchaser Code")
                {
                    ToolTip = 'Specifies the purchaser responsible for this request.';
                }
                field("Assigned User ID"; Rec."Assigned User ID")
                {
                    ToolTip = 'Specifies the user assigned to this request.';
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ToolTip = 'Specifies the currency copied from the purchase order.';
                }
                field("Language Code"; Rec."Language Code")
                {
                    ToolTip = 'Specifies the language used when communicating with the vendor.';
                }
                field("External Reference"; Rec."External Reference")
                {
                    ToolTip = 'Specifies the vendor reference for this request.';
                }
            }
            group(Dates)
            {
                Caption = 'Dates';

                field("Sent Date Time"; Rec."Sent Date Time")
                {
                    Editable = false;
                    ToolTip = 'Specifies when this request was sent to the vendor.';
                }
                field("Response Deadline"; Rec."Response Deadline")
                {
                    ToolTip = 'Specifies the date by which the vendor should respond.';
                }
                field("Closed Date Time"; Rec."Closed Date Time")
                {
                    Editable = false;
                    ToolTip = 'Specifies when this request was closed.';
                }
            }
            part(RequestLines; "AMC Vendor Request Subform")
            {
                Caption = 'Lines';
                SubPageLink = "Request No." = field("No.");
                UpdatePropagation = Both;
            }
            part(CollabTimeline; "AMC Collab Timeline")
            {
                Caption = 'Timeline';
                SubPageLink = "Source Type" = const(Request), "Source No." = field("No.");
            }
            part(VendorAccessLinks; "AMC Vendor Access Links Part")
            {
                Caption = 'Vendor Access Links';
                SubPageLink = "Request No." = field("No.");
            }
            group(Statistics)
            {
                Caption = 'Statistics';

                field("Open Proposal Count"; Rec."Open Proposal Count")
                {
                    ToolTip = 'Specifies the number of proposals awaiting review for this request.';
                }
                field("Line Count"; Rec."Line Count")
                {
                    ToolTip = 'Specifies the number of lines in this request.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AMCSend)
            {
                ApplicationArea = All;
                Caption = 'Send';
                Enabled = this.SendEnabled;
                Image = SendTo;
                ToolTip = 'Sends the vendor request and an access link to the vendor.';

                trigger OnAction()
                begin
                    this.SendRequest();
                end;
            }
            action(AMCResendLink)
            {
                ApplicationArea = All;
                Caption = 'Re-send link';
                Enabled = Rec.Status = Rec.Status::"Awaiting Vendor";
                Image = SendTo;
                ToolTip = 'Supersedes the current access link and sends a new link to the vendor.';

                trigger OnAction()
                begin
                    this.SendRequest();
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        this.SendEnabled := Rec.Status = Rec.Status::Draft;
    end;

    local procedure SendRequest()
    var
        RequestMgt: Codeunit "AMC Request Mgt";
    begin
        RequestMgt.Send(Rec);
        CurrPage.Update(false);
    end;

    var
        SendEnabled: Boolean;
}
