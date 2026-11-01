namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Vendor;
using System.Email;

tableextension 50102 "AMC Vendor Ext" extends Vendor
{
    fields
    {
        field(50100; "AMC Collaboration Enabled"; Boolean)
        {
            Caption = 'Collaboration Enabled';
            ToolTip = 'Specifies whether this vendor can participate in vendor collaboration.';
            DataClassification = SystemMetadata;
        }
        field(50101; "AMC Portal Contact E-Mail"; Text[80])
        {
            Caption = 'Portal Contact Email';
            ToolTip = 'Specifies the email address to which vendor collaboration links are sent. If blank, the vendor email address is used.';
            DataClassification = EndUserIdentifiableInformation;
            ExtendedDatatype = EMail;

            trigger OnValidate()
            var
                MailManagement: Codeunit "Mail Management";
            begin
                if Rec."AMC Portal Contact E-Mail" <> '' then
                    MailManagement.CheckValidEmailAddress(Rec."AMC Portal Contact E-Mail");
            end;
        }
        field(50102; "AMC Response Days"; Integer)
        {
            Caption = 'Response Days';
            ToolTip = 'Specifies the number of days this vendor has to respond. Set to zero to use the default response days from Vendor Collaboration Setup.';
            DataClassification = SystemMetadata;

            trigger OnValidate()
            var
                ResponseDaysMustNotBeNegativeErr: Label '%1 must not be negative.', Comment = '%1 = field caption';
            begin
                if Rec."AMC Response Days" < 0 then
                    Error(ResponseDaysMustNotBeNegativeErr, Rec.FieldCaption("AMC Response Days"));
            end;
        }
    }
}
