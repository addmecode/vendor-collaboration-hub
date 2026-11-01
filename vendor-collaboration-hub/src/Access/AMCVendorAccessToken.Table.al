namespace Addmecode.VendorCollaborationHub;

using System.Security.AccessControl;

table 50106 "AMC Vendor Access Token"
{
    Caption = 'Vendor Access Token';
    DataClassification = CustomerContent;
    DrillDownPageId = "AMC Vendor Access Links";
    LookupPageId = "AMC Vendor Access Links";

    fields
    {
        field(1; "Token Id"; Guid)
        {
            Caption = 'Token Id';
            ToolTip = 'Specifies the non-secret identifier of the vendor access link.';
            DataClassification = SystemMetadata;
        }
        field(2; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            ToolTip = 'Specifies the vendor request that this link authorizes.';
            TableRelation = "AMC Vendor Request";
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            ToolTip = 'Specifies the vendor that this link authorizes.';
        }
        field(4; "Token Hash"; Text[64])
        {
            AllowInCustomizations = Never;
            Caption = 'Token Hash';
            ToolTip = 'Specifies the SHA-256 hash used to look up the access link. The raw access token is not stored in this table.';
            DataClassification = SystemMetadata;
        }
        field(5; Status; Enum "AMC Access Token Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the current status of the vendor access link.';
        }
        field(6; "Issued At"; DateTime)
        {
            Caption = 'Issued At';
            ToolTip = 'Specifies when the vendor access link was issued.';
        }
        field(7; "Expires At"; DateTime)
        {
            Caption = 'Expires At';
            ToolTip = 'Specifies when the vendor access link expires.';
        }
        field(8; "Sent To E-Mail"; Text[80])
        {
            Caption = 'Sent To E-Mail';
            ToolTip = 'Specifies the e-mail address to which the vendor access link was sent.';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(9; "Sent At"; DateTime)
        {
            Caption = 'Sent At';
            ToolTip = 'Specifies when the vendor access link was sent.';
        }
        field(10; "First Accessed At"; DateTime)
        {
            Caption = 'First Accessed At';
            ToolTip = 'Specifies when the vendor access link was first opened.';
        }
        field(11; "Last Accessed At"; DateTime)
        {
            Caption = 'Last Accessed At';
            ToolTip = 'Specifies when the vendor access link was last opened.';
        }
        field(12; "Access Count"; Integer)
        {
            Caption = 'Access Count';
            ToolTip = 'Specifies the number of times the vendor access link was opened.';
        }
        field(13; "Revoked At"; DateTime)
        {
            Caption = 'Revoked At';
            ToolTip = 'Specifies when the vendor access link was revoked.';
        }
        field(14; "Revoked By"; Code[50])
        {
            Caption = 'Revoked By';
            ToolTip = 'Specifies who revoked the vendor access link.';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(15; "Revocation Reason"; Text[250])
        {
            Caption = 'Revocation Reason';
            ToolTip = 'Specifies why the vendor access link was revoked.';
        }
    }

    keys
    {
        key(PK; "Token Id")
        {
            Clustered = true;
        }
        key(TokenHash; "Token Hash")
        {
            Unique = true;
        }
        key(RequestStatus; "Request No.", Status)
        {
        }
        key(StatusExpiresAt; Status, "Expires At")
        {
        }
        key(VendorNo; "Vendor No.")
        {
        }
    }
}
