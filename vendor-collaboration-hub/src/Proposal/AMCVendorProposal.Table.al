namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

table 50103 "AMC Vendor Proposal"
{
    Caption = 'Vendor Proposal';
    DataClassification = CustomerContent;
    DrillDownPageId = "AMC Vendor Proposals";
    LookupPageId = "AMC Vendor Proposals";
    Permissions = tabledata "AMC Vendor Proposal Line" = rd;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
        }
        field(2; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            DataClassification = CustomerContent;
            TableRelation = "AMC Vendor Request";
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            DataClassification = CustomerContent;
            TableRelation = Vendor;
        }
        field(4; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
            DataClassification = CustomerContent;
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Order));
        }
        field(5; Status; Enum "AMC Proposal Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }
        field(6; "Idempotency Key"; Text[64])
        {
            Caption = 'Idempotency Key';
            DataClassification = CustomerContent;
        }
        field(7; "Submitted Date Time"; DateTime)
        {
            Caption = 'Submitted Date Time';
            DataClassification = CustomerContent;
        }
        field(8; "Submitted By"; Text[100])
        {
            Caption = 'Submitted By';
            DataClassification = CustomerContent;
        }
        field(9; "Decision Date Time"; DateTime)
        {
            Caption = 'Decision Date Time';
            DataClassification = CustomerContent;
        }
        field(10; "Decision User ID"; Code[50])
        {
            Caption = 'Decision User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; "Decision Reason"; Text[250])
        {
            Caption = 'Decision Reason';
            DataClassification = CustomerContent;
        }
        field(12; "Applied Date Time"; DateTime)
        {
            Caption = 'Applied Date Time';
            DataClassification = CustomerContent;
        }
        field(13; "Apply Attempt Count"; Integer)
        {
            Caption = 'Apply Attempt Count';
            DataClassification = CustomerContent;
        }
        field(14; "Last Error Code"; Code[20])
        {
            Caption = 'Last Error Code';
            DataClassification = CustomerContent;
        }
        field(15; "Last Error Message"; Text[250])
        {
            Caption = 'Last Error Message';
            DataClassification = CustomerContent;
        }
        field(16; "Correlation Id"; Guid)
        {
            Caption = 'Correlation Id';
            DataClassification = CustomerContent;
        }
        field(17; "Superseded By"; Code[20])
        {
            Caption = 'Superseded By';
            DataClassification = CustomerContent;
            TableRelation = "AMC Vendor Proposal";
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(RequestStatus; "Request No.", Status)
        {
        }
        key(VendorIdempotency; "Vendor No.", "Idempotency Key")
        {
            Unique = true;
        }
        key(StatusSubmittedDateTime; Status, "Submitted Date Time")
        {
        }
    }

    trigger OnDelete()
    var
        VendorProposalLine: Record "AMC Vendor Proposal Line";
    begin
        VendorProposalLine.SetRange("Proposal No.", Rec."No.");
        VendorProposalLine.DeleteAll(true);
    end;
}
