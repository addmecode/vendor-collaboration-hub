namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

table 50103 "AMC Vendor Proposal"
{
    Caption = 'Vendor Proposal';
    DataClassification = CustomerContent;
    DrillDownPageId = "AMC Vendor Proposals";
    LookupPageId = "AMC Vendor Proposals";
    Permissions = tabledata "AMC Vendor Proposal" = r,
                  tabledata "AMC Vendor Proposal Line" = d;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
        }
        field(2; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            TableRelation = "AMC Vendor Request";
            ValidateTableRelation = false;
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
            ValidateTableRelation = false;
        }
        field(4; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Order));
        }
        field(5; Status; Enum "AMC Proposal Status")
        {
            Caption = 'Status';
        }
        field(6; "Idempotency Key"; Text[64])
        {
            Caption = 'Idempotency Key';
        }
        field(7; "Submitted Date Time"; DateTime)
        {
            Caption = 'Submitted Date Time';
        }
        field(8; "Submitted By"; Text[100])
        {
            Caption = 'Submitted By';
        }
        field(9; "Decision Date Time"; DateTime)
        {
            Caption = 'Decision Date Time';
        }
        field(10; "Decision User ID"; Code[50])
        {
            Caption = 'Decision User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; "Decision Reason"; Text[250])
        {
            Caption = 'Decision Reason';
        }
        field(12; "Applied Date Time"; DateTime)
        {
            Caption = 'Applied Date Time';
        }
        field(13; "Apply Attempt Count"; Integer)
        {
            Caption = 'Apply Attempt Count';
        }
        field(14; "Last Error Code"; Code[20])
        {
            Caption = 'Last Error Code';
        }
        field(15; "Last Error Message"; Text[250])
        {
            Caption = 'Last Error Message';
        }
        field(16; "Correlation Id"; Guid)
        {
            Caption = 'Correlation Id';
        }
        field(17; "Superseded By"; Code[20])
        {
            Caption = 'Superseded By';
            TableRelation = "AMC Vendor Proposal";
        }
        field(18; "Payload Hash"; Text[64])
        {
            Caption = 'Payload Hash';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(19; "External Reference"; Text[100])
        {
            Caption = 'External Reference';
        }
        field(20; "API Submission Pending"; Boolean)
        {
            Caption = 'API Submission Pending';
            DataClassification = SystemMetadata;
            Editable = false;
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

    trigger OnInsert()
    var
        ExistingVendorProposal: Record "AMC Vendor Proposal";
        DuplicateIdempotencyKeyErr: Label 'A proposal with idempotency key %1 already exists for vendor %2.', Comment = '%1 = idempotency key, %2 = vendor number';
    begin
        ExistingVendorProposal.SetRange("Vendor No.", Rec."Vendor No.");
        ExistingVendorProposal.SetRange("Idempotency Key", Rec."Idempotency Key");
        if not ExistingVendorProposal.IsEmpty() then
            Error(DuplicateIdempotencyKeyErr, Rec."Idempotency Key", Rec."Vendor No.");
    end;

  procedure InitRecord()
  begin
    Rec.Status := Rec.Status::Draft;
  end;
}
