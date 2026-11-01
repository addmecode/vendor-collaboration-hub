namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Configures collaboration activation, numbering, portal links, notifications and proposal validation policies.
/// </summary>
page 50100 "AMC Collaboration Setup"
{
    ApplicationArea = All;
    Caption = 'Vendor Collaboration Setup';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "AMC Collaboration Setup";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(Status)
            {
                Caption = 'Status';
                field(Enabled; Rec.Enabled)
                {

                    trigger OnValidate()
                    begin
                        this.UpdateSetupFieldsEditable();
                        CurrPage.Update(false);
                    end;
                }
            }
            group(General)
            {
                Caption = 'General';
                Editable = this.SetupFieldsEditable;

                field("Request Nos."; Rec."Request Nos.")
                {
                }
                field("Proposal Nos."; Rec."Proposal Nos.")
                {
                }
                field("Default Response Days"; Rec."Default Response Days")
                {
                }
                field("Allow Item Substitution"; Rec."Allow Item Substitution")
                {
                }
                field("Allow Quantity Increase"; Rec."Allow Quantity Increase")
                {
                }
                field("Max Splits per Line"; Rec."Max Splits per Line")
                {
                }
                field("Require Reason Code"; Rec."Require Reason Code")
                {
                }
            }
            group(Portal)
            {
                Caption = 'Portal';
                Editable = this.SetupFieldsEditable;

                field("Portal Base URL"; Rec."Portal Base URL")
                {
                }
                field("Portal Support E-Mail"; Rec."Portal Support E-Mail")
                {
                }
                field("Link Validity Days"; Rec."Link Validity Days")
                {
                }
            }
            group(Email)
            {
                Caption = 'Email';
                Editable = this.SetupFieldsEditable;

                field("Attach Order PDF"; Rec."Attach Order PDF")
                {
                }
            }
            group(Telemetry)
            {
                Caption = 'Telemetry';
                Editable = this.SetupFieldsEditable;

                field("Telemetry Verbosity"; Rec."Telemetry Verbosity")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AMCScheduleTokenExpiryJob)
            {
                ApplicationArea = All;
                Caption = 'Schedule token expiry job';
                Image = Job;
                ToolTip = 'Schedules the recurring job that marks expired vendor access links as expired.';

                trigger OnAction()
                begin
                    this.ScheduleTokenExpiryJob();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.EnsureSetup();
        this.UpdateSetupFieldsEditable();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        this.UpdateSetupFieldsEditable();
    end;

    local procedure EnsureSetup()
    begin
        if not Rec.Get() then
            Rec.GetSetup();
    end;

    local procedure UpdateSetupFieldsEditable()
    begin
        this.SetupFieldsEditable := not Rec.Enabled;
    end;

    local procedure ScheduleTokenExpiryJob()
    var
        TokenExpiryJob: Codeunit "AMC Token Expiry Job";
        ExistingTokenExpiryJobMsg: Label 'The token expiry job is already scheduled. No new job queue entry was created.';
    begin
        if not TokenExpiryJob.ScheduleTokenExpiryJob() then
            Message(ExistingTokenExpiryJobMsg);
    end;

    var
        SetupFieldsEditable: Boolean;
}
