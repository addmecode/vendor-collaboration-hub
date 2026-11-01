namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using System.Email;
using System.Integration;

table 50100 "AMC Collaboration Setup"
{
    Caption = 'Vendor Collaboration Setup';
    DataClassification = SystemMetadata;
    Permissions = tabledata "AMC Collaboration Setup" = ri;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            AllowInCustomizations = Never;
            Caption = 'Primary Key';
            ToolTip = 'Specifies the key of the single collaboration setup record. The key is always blank.';
            NotBlank = false;
        }
        field(2; Enabled; Boolean)
        {
            Caption = 'Enabled';
            ToolTip = 'Specifies whether vendor collaboration is enabled.';

            trigger OnValidate()
            begin
                if this.Enabled and not xRec.Enabled then
                    this.ValidateSetupForActivation();
            end;
        }
        field(3; "Request Nos."; Code[20])
        {
            Caption = 'Request Nos.';
            ToolTip = 'Specifies the number series used for vendor requests.';
            TableRelation = "No. Series";
        }
        field(4; "Proposal Nos."; Code[20])
        {
            Caption = 'Proposal Nos.';
            ToolTip = 'Specifies the number series used for vendor proposals.';
            TableRelation = "No. Series";
        }
        field(5; "Default Response Days"; Integer)
        {
            Caption = 'Default Response Days';
            ToolTip = 'Specifies the default number of days a vendor has to respond.';
        }
        field(6; "Allow Item Substitution"; Boolean)
        {
            Caption = 'Allow Item Substitution';
            ToolTip = 'Specifies whether vendors can propose substitute items.';
        }
        field(7; "Allow Quantity Increase"; Boolean)
        {
            Caption = 'Allow Quantity Increase';
            ToolTip = 'Specifies whether vendors can propose quantities above the requested quantity.';
        }
        field(8; "Max Splits per Line"; Integer)
        {
            Caption = 'Max Splits per Line';
            ToolTip = 'Specifies the maximum number of proposed deliveries for one request line.';
        }
        field(9; "Require Reason Code"; Boolean)
        {
            Caption = 'Require Reason Code';
            ToolTip = 'Specifies whether non-confirmation proposal lines require a reason code.';
        }
        field(10; "Portal Base URL"; Text[250])
        {
            Caption = 'Portal Base URL';
            ToolTip = 'Specifies the base URL used to build vendor access links.';
            ExtendedDatatype = URL;
        }
        field(11; "Portal Support E-Mail"; Text[80])
        {
            Caption = 'Portal Support E-Mail';
            ToolTip = 'Specifies the support email address shown when a vendor access link cannot be used.';
            DataClassification = CustomerContent;
            ExtendedDatatype = EMail;
        }
        field(12; "Link Validity Days"; Integer)
        {
            Caption = 'Link Validity Days';
            ToolTip = 'Specifies how many days a vendor access link remains valid.';
        }
        field(13; "Attach Order PDF"; Boolean)
        {
            Caption = 'Attach Order PDF';
            ToolTip = 'Specifies whether the purchase order PDF is attached to the vendor email.';
        }
        field(14; "Telemetry Verbosity"; Enum "AMC Telemetry Verbosity")
        {
            Caption = 'Telemetry Verbosity';
            ToolTip = 'Specifies the telemetry verbosity used by vendor collaboration.';
            InitValue = Normal;
            ValuesAllowed = Normal, Warning, Error, Verbose;
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
        this.Validate(Enabled, false);
        this.Validate("Default Response Days", 7);
        this.Validate("Allow Item Substitution", false);
        this.Validate("Allow Quantity Increase", false);
        this.Validate("Max Splits per Line", 3);
        this.Validate("Require Reason Code", true);
        this.Validate("Link Validity Days", 14);
        this.Validate("Telemetry Verbosity", this."Telemetry Verbosity"::Normal);
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
