namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using System.Email;
using System.Integration;

table 50100 "AMC Collaboration Setup"
{
    Caption = 'Vendor Collaboration Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; Enabled; Boolean)
        {
            Caption = 'Enabled';
            DataClassification = SystemMetadata;

            trigger OnValidate()
            begin
                if this.Enabled and not xRec.Enabled then
                    this.ValidateSetupForActivation();
            end;
        }
        field(3; "Request Nos."; Code[20])
        {
            Caption = 'Request Nos.';
            DataClassification = SystemMetadata;
            TableRelation = "No. Series";
        }
        field(4; "Proposal Nos."; Code[20])
        {
            Caption = 'Proposal Nos.';
            DataClassification = SystemMetadata;
            TableRelation = "No. Series";
        }
        field(5; "Default Response Days"; Integer)
        {
            Caption = 'Default Response Days';
            DataClassification = SystemMetadata;
        }
        field(6; "Allow Item Substitution"; Boolean)
        {
            Caption = 'Allow Item Substitution';
            DataClassification = SystemMetadata;
        }
        field(7; "Allow Quantity Increase"; Boolean)
        {
            Caption = 'Allow Quantity Increase';
            DataClassification = SystemMetadata;
        }
        field(8; "Max Splits per Line"; Integer)
        {
            Caption = 'Max Splits per Line';
            DataClassification = SystemMetadata;
        }
        field(9; "Require Reason Code"; Boolean)
        {
            Caption = 'Require Reason Code';
            DataClassification = SystemMetadata;
        }
        field(10; "Portal Base URL"; Text[250])
        {
            Caption = 'Portal Base URL';
            DataClassification = SystemMetadata;
            ExtendedDatatype = URL;
        }
        field(11; "Portal Support E-Mail"; Text[80])
        {
            Caption = 'Portal Support E-Mail';
            DataClassification = CustomerContent;
            ExtendedDatatype = EMail;
        }
        field(12; "Link Validity Days"; Integer)
        {
            Caption = 'Link Validity Days';
            DataClassification = SystemMetadata;
        }
        field(13; "Attach Order PDF"; Boolean)
        {
            Caption = 'Attach Order PDF';
            DataClassification = SystemMetadata;
        }
        field(14; "Telemetry Verbosity"; Option)
        {
            Caption = 'Telemetry Verbosity';
            DataClassification = SystemMetadata;
            OptionCaption = 'Normal,Warning,Error,Verbose';
            OptionMembers = Normal,Warning,Error,Verbose;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        this.InitializeDefaults();
    end;

    trigger OnModify()
    var
        PersistedCollaborationSetup: Record "AMC Collaboration Setup";
    begin
        if PersistedCollaborationSetup.Get(Rec."Primary Key") then
            if Rec.Enabled and not PersistedCollaborationSetup.Enabled then
                this.ValidateSetupForActivation();
    end;

    procedure GetSetup()
    begin
        if not this.Get() then begin
            this.Init();
            this.Insert(true);
        end;
    end;

    local procedure InitializeDefaults()
    begin
        this.Enabled := false;
        this."Default Response Days" := 7;
        this."Allow Item Substitution" := false;
        this."Allow Quantity Increase" := false;
        this."Max Splits per Line" := 3;
        this."Require Reason Code" := true;
        this."Link Validity Days" := 14;
        this."Telemetry Verbosity" := this."Telemetry Verbosity"::Normal;
    end;

    local procedure ValidateSetupForActivation()
    var
        MailManagement: Codeunit "Mail Management";
        WebRequestHelper: Codeunit "Web Request Helper";
        FieldMustBeGreaterThanOrEqualToErr: Label '%1 must be greater than or equal to %2.', Comment = '%1 = field caption, %2 = field caption';
        FieldMustBeGreaterThanZeroErr: Label '%1 must be greater than zero.', Comment = '%1 = field caption';
    begin
        this.TestField("Request Nos.");
        this.TestField("Proposal Nos.");
        this.TestField("Portal Base URL");
        this.TestField("Portal Support E-Mail");
        WebRequestHelper.IsHttpUrl(this."Portal Base URL");
        MailManagement.CheckValidEmailAddress(this."Portal Support E-Mail");
        if this."Default Response Days" <= 0 then
            Error(FieldMustBeGreaterThanZeroErr, this.FieldCaption("Default Response Days"));
        if this."Link Validity Days" <= 0 then
            Error(FieldMustBeGreaterThanZeroErr, this.FieldCaption("Link Validity Days"));
        if this."Default Response Days" > this."Link Validity Days" then
            Error(FieldMustBeGreaterThanOrEqualToErr, this.FieldCaption("Link Validity Days"), this.FieldCaption("Default Response Days"));
        if this."Max Splits per Line" <= 0 then
            Error(FieldMustBeGreaterThanZeroErr, this.FieldCaption("Max Splits per Line"));
    end;
}
