namespace Addmecode.VendorCollaborationHub;

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
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether vendor collaboration is enabled.';

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
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series used for vendor requests.';
                }
                field("Proposal Nos."; Rec."Proposal Nos.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number series used for vendor proposals.';
                }
                field("Default Response Days"; Rec."Default Response Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default number of days a vendor has to respond.';
                }
                field("Allow Item Substitution"; Rec."Allow Item Substitution")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether vendors can propose substitute items.';
                }
                field("Allow Quantity Increase"; Rec."Allow Quantity Increase")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether vendors can propose quantities above the requested quantity.';
                }
                field("Max Splits per Line"; Rec."Max Splits per Line")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum number of proposed deliveries for one request line.';
                }
                field("Require Reason Code"; Rec."Require Reason Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether non-confirmation proposal lines require a reason code.';
                }
            }
            group(Portal)
            {
                Caption = 'Portal';
                Editable = this.SetupFieldsEditable;

                field("Portal Base URL"; Rec."Portal Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base URL used to build vendor access links.';
                }
                field("Portal Support E-Mail"; Rec."Portal Support E-Mail")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the support email address shown when a vendor access link cannot be used.';
                }
                field("Link Validity Days"; Rec."Link Validity Days")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many days a vendor access link remains valid.';
                }
            }
            group(Email)
            {
                Caption = 'Email';
                Editable = this.SetupFieldsEditable;

                field("Attach Order PDF"; Rec."Attach Order PDF")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the purchase order PDF is attached to the vendor email.';
                }
            }
            group(Telemetry)
            {
                Caption = 'Telemetry';
                Editable = this.SetupFieldsEditable;

                field("Telemetry Verbosity"; Rec."Telemetry Verbosity")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the telemetry verbosity used by vendor collaboration.';
                }
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

    var
        SetupFieldsEditable: Boolean;
}
