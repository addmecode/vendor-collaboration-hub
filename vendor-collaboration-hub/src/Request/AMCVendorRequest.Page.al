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
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

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
                field("Purchaser Code"; Rec."Purchaser Code")
                {
                }
                field("Assigned User ID"; Rec."Assigned User ID")
                {
                }
                field("Currency Code"; Rec."Currency Code")
                {
                }
                field("Language Code"; Rec."Language Code")
                {
                }
                field("External Reference"; Rec."External Reference")
                {
                }
            }
            group(Dates)
            {
                Caption = 'Dates';

                field("Sent Date Time"; Rec."Sent Date Time")
                {
                    Editable = false;
                }
                field("Response Deadline"; Rec."Response Deadline")
                {
                }
                field("Closed Date Time"; Rec."Closed Date Time")
                {
                    Editable = false;
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
                }
                field("Line Count"; Rec."Line Count")
                {
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
