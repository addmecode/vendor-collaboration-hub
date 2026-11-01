namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

/// <summary>
/// Stores proposal identity, submission and idempotency data, buyer decisions and application results.
/// </summary>
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
            ToolTip = 'Specifies the vendor proposal number.';
            NotBlank = true;
        }
        field(2; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            ToolTip = 'Specifies the vendor request answered by this proposal.';
            TableRelation = "AMC Vendor Request";
            ValidateTableRelation = false;
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            ToolTip = 'Specifies the vendor that made this proposal.';
            TableRelation = Vendor;
            ValidateTableRelation = false;
        }
        field(4; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
            ToolTip = 'Specifies the purchase order answered by this proposal.';
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Order));
        }
        field(5; Status; Enum "AMC Proposal Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the current status of the vendor proposal.';
        }
        field(6; "Idempotency Key"; Text[64])
        {
            Caption = 'Idempotency Key';
            ToolTip = 'Specifies the caller key used to prevent duplicate proposal submissions.';
        }
        field(7; "Submitted Date Time"; DateTime)
        {
            Caption = 'Submitted Date Time';
            ToolTip = 'Specifies when the vendor submitted this proposal.';
        }
        field(8; "Submitted By"; Text[100])
        {
            Caption = 'Submitted By';
            ToolTip = 'Specifies the vendor contact that submitted this proposal.';
        }
        field(9; "Decision Date Time"; DateTime)
        {
            Caption = 'Decision Date Time';
            ToolTip = 'Specifies when a decision was made for this proposal.';
        }
        field(10; "Decision User ID"; Code[50])
        {
            Caption = 'Decision User ID';
            ToolTip = 'Specifies the user who made the decision for this proposal.';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; "Decision Reason"; Text[250])
        {
            Caption = 'Decision Reason';
            ToolTip = 'Specifies the reason recorded for the proposal decision.';
        }
        field(12; "Applied Date Time"; DateTime)
        {
            Caption = 'Applied Date Time';
            ToolTip = 'Specifies when this proposal was applied to the purchase order.';
        }
        field(13; "Apply Attempt Count"; Integer)
        {
            Caption = 'Apply Attempt Count';
            ToolTip = 'Specifies the number of attempts to apply this proposal.';
        }
        field(14; "Last Error Code"; Code[20])
        {
            Caption = 'Last Error Code';
            ToolTip = 'Specifies the most recent error code from applying this proposal.';
        }
        field(15; "Last Error Message"; Text[250])
        {
            Caption = 'Last Error Message';
            ToolTip = 'Specifies the most recent error message from applying this proposal.';
        }
        field(16; "Correlation Id"; Guid)
        {
            Caption = 'Correlation Id';
            ToolTip = 'Specifies the identifier that correlates this proposal with telemetry.';
        }
        field(17; "Superseded By"; Code[20])
        {
            Caption = 'Superseded By';
            ToolTip = 'Specifies the proposal that superseded this proposal.';
            TableRelation = "AMC Vendor Proposal";
        }
        field(18; "Payload Hash"; Text[64])
        {
            AllowInCustomizations = Never;
            Caption = 'Payload Hash';
            ToolTip = 'Specifies the hash of the normalized proposal payload used to detect retries with changed content.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(19; "External Reference"; Text[100])
        {
            AllowInCustomizations = AsReadOnly;
            Caption = 'External Reference';
            ToolTip = 'Specifies the external reference supplied by the vendor for this proposal.';
        }
        field(20; "API Submission Pending"; Boolean)
        {
            AllowInCustomizations = Never;
            Caption = 'API Submission Pending';
            ToolTip = 'Specifies whether the proposal is awaiting completion of its API deep insert.';
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

  /// <summary>
  /// Initializes the current proposal buffer to Draft without inserting or persisting it.
  /// </summary>
  procedure InitRecord()
  begin
    Rec.Validate(Status, Rec.Status::Draft);
  end;
}
