namespace Addmecode.VendorCollaborationHub;

page 50122 "AMC Vendor Proposal API"
{
  PageType = API;
  APIPublisher = 'addmecode';
  APIGroup = 'collaboration';
  APIVersion = 'v1.0';
  Caption = 'Vendor Proposal API';
  EntityName = 'vendorProposal';
  EntitySetName = 'vendorProposals';
  SourceTable = "AMC Vendor Proposal";
  Permissions = tabledata "AMC Vendor Proposal" = m;
  ODataKeyFields = SystemId;
  DelayedInsert = true;
  Extensible = false;
  InsertAllowed = true;
  ModifyAllowed = false;
  DeleteAllowed = false;

  layout
  {
    area(Content)
    {
      repeater(General)
      {
        field(id; Rec.SystemId) { Editable = false; }
        field(number; Rec."No.") { Editable = false; }
        field(requestNumber; Rec."Request No.") { }
        field(vendorNumber; Rec."Vendor No.") { }
        field(accessTokenId; this.AccessTokenId) { }
        field(idempotencyKey; Rec."Idempotency Key") { }
        field(submittedBy; Rec."Submitted By") { }
        field(externalReference; Rec."External Reference") { }
        field(correlationId; Rec."Correlation Id") { }
        field(purchaseOrderNumber; Rec."Purchase Order No.") { Editable = false; }
        field(status; Rec.Status) { Editable = false; }
        field(submittedDateTime; Rec."Submitted Date Time") { Editable = false; }
        field(lastModifiedDateTime; Rec.SystemModifiedAt) { Editable = false; }
      }
      part(vendorProposalLines; "AMC Vendor Proposal Line API")
      {
        EntityName = 'vendorProposalLine';
        EntitySetName = 'vendorProposalLines';
        SubPageLink = "Proposal No." = field("No.");
      }
    }
  }

  trigger OnInsertRecord(BelowxRec: Boolean): Boolean
  begin
    this.BeginSubmission();
    exit(false);
  end;

  trigger OnAfterGetRecord()
  begin
    this.CompleteSubmission();
  end;

  trigger OnModifyRecord(): Boolean
  begin
    this.RejectMutation();
  end;

  trigger OnDeleteRecord(): Boolean
  begin
    this.RejectMutation();
  end;

  local procedure BeginSubmission()
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    // Staging replaces the stored key with a transaction-local placeholder.
    // Keep the caller's key separately until all child inserts have completed.
    this.SubmissionIdempotencyKey := Rec."Idempotency Key";
    ProposalMgt.BeginApiSubmission(Rec, this.AccessTokenId, this.SubmissionIdempotencyKey);
    this.PendingSubmissionId := Rec.SystemId;
  end;

  local procedure CompleteSubmission()
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    // The intended POST lifecycle runs this after child inserts and before commit.
    // Target-runtime HTTP verification is still required. GET never submits.
    if not IsNullGuid(this.PendingSubmissionId) and (Rec.SystemId = this.PendingSubmissionId) then begin
      ProposalMgt.CompleteApiSubmission(Rec, this.AccessTokenId, this.SubmissionIdempotencyKey);
      Clear(this.PendingSubmissionId);
      Clear(this.SubmissionIdempotencyKey);
    end;
  end;

  local procedure RejectMutation()
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    ProposalMgt.AssertApiWriteOnce();
  end;

  var
    AccessTokenId: Guid;
    SubmissionIdempotencyKey: Text[64];
    PendingSubmissionId: Guid;
}
