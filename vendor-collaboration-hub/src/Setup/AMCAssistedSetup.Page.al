namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using System.Environment.Configuration;

page 50101 "AMC Assisted Setup"
{
    ApplicationArea = All;
    Caption = 'Set Up Vendor Collaboration';
    Editable = true;
    PageType = NavigatePage;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(Welcome)
            {
                Caption = 'Welcome';
                InstructionalText = 'Use this assisted setup to configure Vendor Collaboration. You will choose number series, define collaboration rules, specify portal and document settings, and choose whether to enable the feature.';
                Visible = this.ShowWelcomeStep;
            }
            group(NumberSeries)
            {
                Caption = 'Number Series';
                InstructionalText = 'Choose the number series that Vendor Collaboration uses for requests and proposals.';
                Visible = this.ShowNumberSeriesStep;

                field("Request Nos."; this.RequestNoSeriesCode)
                {
                    ApplicationArea = All;
                    Editable = true;
                    ShowMandatory = true;
                    TableRelation = "No. Series";
                    Caption = 'Request Nos.';
                    ToolTip = 'Specifies the number series used for vendor requests.';
                }
                field("Proposal Nos."; this.ProposalNoSeriesCode)
                {
                    ApplicationArea = All;
                    Editable = true;
                    ShowMandatory = true;
                    TableRelation = "No. Series";
                    Caption = 'Proposal Nos.';
                    ToolTip = 'Specifies the number series used for vendor proposals.';
                }
            }
            group(CollaborationRules)
            {
                Caption = 'Collaboration Rules';
                InstructionalText = 'Specify the default rules used when collaborating with vendors.';
                Visible = this.ShowCollaborationRulesStep;

                field(DefaultResponseDays; this.DefaultResponseDays)
                {
                    ApplicationArea = All;
                    Caption = 'Default Response Days';
                    ToolTip = 'Specifies the default number of days that a vendor has to respond.';
                }
                field(LinkValidityDays; this.LinkValidityDays)
                {
                    ApplicationArea = All;
                    Caption = 'Link Validity Days';
                    ToolTip = 'Specifies the number of days that a vendor collaboration link remains valid.';
                }
                field(AllowItemSubstitution; this.AllowItemSubstitution)
                {
                    ApplicationArea = All;
                    Caption = 'Allow Item Substitution';
                    ToolTip = 'Specifies whether vendors can propose substitute items.';
                }
                field(AllowQuantityIncrease; this.AllowQuantityIncrease)
                {
                    ApplicationArea = All;
                    Caption = 'Allow Quantity Increase';
                    ToolTip = 'Specifies whether vendors can propose a higher quantity.';
                }
                field(MaxSplitsPerLine; this.MaxSplitsPerLine)
                {
                    ApplicationArea = All;
                    Caption = 'Max Splits per Line';
                    ToolTip = 'Specifies the maximum number of vendor proposals that can split one request line.';
                }
                field(RequireReasonCode; this.RequireReasonCode)
                {
                    ApplicationArea = All;
                    Caption = 'Require Reason Code';
                    ToolTip = 'Specifies whether a reason code is required for vendor responses.';
                }
            }
            group(PortalAndDocuments)
            {
                Caption = 'Portal and Documents';
                InstructionalText = 'Specify the portal details and documents available to vendors.';
                Visible = this.ShowPortalAndDocumentsStep;

                field(PortalBaseUrl; this.PortalBaseUrl)
                {
                    ApplicationArea = All;
                    Caption = 'Portal Base URL';
                    ExtendedDatatype = URL;
                    ToolTip = 'Specifies the base URL of the vendor collaboration portal.';
                }
                field(PortalSupportEmail; this.PortalSupportEmail)
                {
                    ApplicationArea = All;
                    Caption = 'Portal Support E-Mail';
                    ExtendedDatatype = EMail;
                    ToolTip = 'Specifies the e-mail address that vendors can use to request support.';
                }
                field(AttachOrderPdf; this.AttachOrderPdf)
                {
                    ApplicationArea = All;
                    Caption = 'Attach Order PDF';
                    ToolTip = 'Specifies whether to attach the purchase order PDF to vendor communications.';
                }
            }
            group(EnableVendorCollaboration)
            {
                Caption = 'Enable Vendor Collaboration';
                InstructionalText = 'Select Enable to make Vendor Collaboration available when you finish the setup.';
                Visible = this.ShowEnableStep;

                field(Enabled; this.Enabled)
                {
                    ApplicationArea = All;
                    Caption = 'Enable Vendor Collaboration';
                    ToolTip = 'Specifies whether Vendor Collaboration is enabled when the setup is completed.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Back)
            {
                ApplicationArea = All;
                Caption = 'Back';
                Enabled = this.CanGoBack;
                Image = PreviousRecord;
                InFooterBar = true;
                ToolTip = 'Returns to the previous step.';

                trigger OnAction()
                begin
                    this.GoToPreviousStep();
                end;
            }
            action("Next")
            {
                ApplicationArea = All;
                Caption = 'Next';
                Enabled = this.CanGoNext;
                Image = NextRecord;
                InFooterBar = true;
                ToolTip = 'Continues to the next step.';

                trigger OnAction()
                begin
                    this.GoToNextStep();
                end;
            }
            action(Finish)
            {
                ApplicationArea = All;
                Caption = 'Finish';
                Enabled = this.ShowEnableStep;
                Image = Approve;
                InFooterBar = true;
                ToolTip = 'Saves the selected settings and completes the setup.';

                trigger OnAction()
                begin
                    this.FinishSetup();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.InitializePage();
    end;

    local procedure InitializePage()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
        CollaborationSetupPage: Page "AMC Collaboration Setup";
        AssistedSetupNotAvailableError: ErrorInfo;
        AssistedSetupNotAvailableErr: Label 'Vendor Collaboration is already enabled. Use the %1 page to change the configuration.', Comment = '%1 = page caption';
        OpenCollaborationSetupLbl: Label 'Open %1', Comment = '%1 = page caption';
    begin
        if CollaborationSetup.Get() then begin
            if CollaborationSetup.Enabled then begin
                AssistedSetupNotAvailableError.Message := StrSubstNo(AssistedSetupNotAvailableErr, CollaborationSetupPage.Caption());
                AssistedSetupNotAvailableError.PageNo := Page::"AMC Collaboration Setup";
                AssistedSetupNotAvailableError.AddNavigationAction(StrSubstNo(OpenCollaborationSetupLbl, CollaborationSetupPage.Caption()));
                Error(AssistedSetupNotAvailableError);
            end;

            this.LoadSetup(CollaborationSetup)
        end else begin
            TempCollaborationSetup.GetSetup();
            this.LoadSetup(TempCollaborationSetup);
        end;

        this.SetCurrentStep(1, false);
    end;

    local procedure GoToPreviousStep()
    begin
        this.SetCurrentStep(this.CurrentStep - 1, true);
    end;

    local procedure GoToNextStep()
    begin
        this.SetCurrentStep(this.CurrentStep + 1, true);
    end;

    local procedure SetCurrentStep(NewStep: Integer; RefreshPage: Boolean)
    begin
        this.CurrentStep := NewStep;
        this.ShowWelcomeStep := false;
        this.ShowNumberSeriesStep := false;
        this.ShowCollaborationRulesStep := false;
        this.ShowPortalAndDocumentsStep := false;
        this.ShowEnableStep := false;

        case this.CurrentStep of
            1:
                this.ShowWelcomeStep := true;
            2:
                this.ShowNumberSeriesStep := true;
            3:
                this.ShowCollaborationRulesStep := true;
            4:
                this.ShowPortalAndDocumentsStep := true;
            5:
                this.ShowEnableStep := true;
        end;

        this.CanGoBack := this.CurrentStep > 1;
        this.CanGoNext := this.CurrentStep < 5;
        if RefreshPage then
            CurrPage.Update(false);
    end;

    local procedure FinishSetup()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        GuidedExperience: Codeunit "Guided Experience";
    begin
        if not CollaborationSetup.Get() then begin
            CollaborationSetup.Init();
            CollaborationSetup.Insert(true);
        end;

        this.ApplySetupValues(CollaborationSetup);
        CollaborationSetup.Modify(true);

        GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"AMC Assisted Setup");
        CurrPage.Close();
    end;

    local procedure ApplySetupValues(var CollaborationSetup: Record "AMC Collaboration Setup")
    begin
        CollaborationSetup."Request Nos." := this.RequestNoSeriesCode;
        CollaborationSetup."Proposal Nos." := this.ProposalNoSeriesCode;
        CollaborationSetup."Default Response Days" := this.DefaultResponseDays;
        CollaborationSetup."Link Validity Days" := this.LinkValidityDays;
        CollaborationSetup."Allow Item Substitution" := this.AllowItemSubstitution;
        CollaborationSetup."Allow Quantity Increase" := this.AllowQuantityIncrease;
        CollaborationSetup."Max Splits per Line" := this.MaxSplitsPerLine;
        CollaborationSetup."Require Reason Code" := this.RequireReasonCode;
        CollaborationSetup."Portal Base URL" := this.PortalBaseUrl;
        CollaborationSetup."Portal Support E-Mail" := this.PortalSupportEmail;
        CollaborationSetup."Attach Order PDF" := this.AttachOrderPdf;
        CollaborationSetup.Validate(Enabled, this.Enabled);
    end;

    local procedure LoadSetup(CollaborationSetup: Record "AMC Collaboration Setup")
    begin
        this.Enabled := CollaborationSetup.Enabled;
        this.RequestNoSeriesCode := CollaborationSetup."Request Nos.";
        this.ProposalNoSeriesCode := CollaborationSetup."Proposal Nos.";
        this.DefaultResponseDays := CollaborationSetup."Default Response Days";
        this.LinkValidityDays := CollaborationSetup."Link Validity Days";
        this.AllowItemSubstitution := CollaborationSetup."Allow Item Substitution";
        this.AllowQuantityIncrease := CollaborationSetup."Allow Quantity Increase";
        this.MaxSplitsPerLine := CollaborationSetup."Max Splits per Line";
        this.RequireReasonCode := CollaborationSetup."Require Reason Code";
        this.PortalBaseUrl := CollaborationSetup."Portal Base URL";
        this.PortalSupportEmail := CollaborationSetup."Portal Support E-Mail";
        this.AttachOrderPdf := CollaborationSetup."Attach Order PDF";
    end;

    var
        AllowItemSubstitution: Boolean;
        AllowQuantityIncrease: Boolean;
        AttachOrderPdf: Boolean;
        CanGoBack: Boolean;
        CanGoNext: Boolean;
        CurrentStep: Integer;
        DefaultResponseDays: Integer;
        Enabled: Boolean;
        LinkValidityDays: Integer;
        MaxSplitsPerLine: Integer;
        PortalBaseUrl: Text[250];
        PortalSupportEmail: Text[80];
        ProposalNoSeriesCode: Code[20];
        RequestNoSeriesCode: Code[20];
        RequireReasonCode: Boolean;
        ShowCollaborationRulesStep: Boolean;
        ShowNumberSeriesStep: Boolean;
        ShowPortalAndDocumentsStep: Boolean;
        ShowEnableStep: Boolean;
        ShowWelcomeStep: Boolean;
}
