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
            DataClassification = SystemMetadata;
        }
        field(2; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            TableRelation = "AMC Vendor Request";
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
        }
        field(4; "Token Hash"; Text[64])
        {
            Caption = 'Token Hash';
            DataClassification = SystemMetadata;
        }
        field(5; Status; Enum "AMC Access Token Status")
        {
            Caption = 'Status';
        }
        field(6; "Issued At"; DateTime)
        {
            Caption = 'Issued At';
        }
        field(7; "Expires At"; DateTime)
        {
            Caption = 'Expires At';
        }
        field(8; "Sent To E-Mail"; Text[80])
        {
            Caption = 'Sent To E-Mail';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(9; "Sent At"; DateTime)
        {
            Caption = 'Sent At';
        }
        field(10; "First Accessed At"; DateTime)
        {
            Caption = 'First Accessed At';
        }
        field(11; "Last Accessed At"; DateTime)
        {
            Caption = 'Last Accessed At';
        }
        field(12; "Access Count"; Integer)
        {
            Caption = 'Access Count';
        }
        field(13; "Revoked At"; DateTime)
        {
            Caption = 'Revoked At';
        }
        field(14; "Revoked By"; Code[50])
        {
            Caption = 'Revoked By';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(15; "Revocation Reason"; Text[250])
        {
            Caption = 'Revocation Reason';
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
    }
}
