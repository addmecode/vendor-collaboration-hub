namespace Addmecode.VendorCollaborationHub;

page 50123 "AMC Vendor Proposal Line API"
{
  PageType = API;
  APIPublisher = 'addmecode';
  APIGroup = 'collaboration';
  APIVersion = 'v1.0';
  Caption = 'Vendor Proposal Line API';
  EntityName = 'vendorProposalLine';
  EntitySetName = 'vendorProposalLines';
  SourceTable = "AMC Vendor Proposal Line";
  ODataKeyFields = SystemId;
  DelayedInsert = true;
  PopulateAllFields = true;
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
        field(lineNumber; Rec."Line No.") { Editable = false; }
        field(requestLineNumber; Rec."Request Line No.") { }
        field(lineType; Rec."Line Type") { }
        field(sequenceNumber; Rec."Sequence No.") { }
        field(proposedItemNumber; this.ProposedItemNumber) { }
        field(proposedVariantCode; this.ProposedVariantCode) { }
        field(proposedQuantity; Rec."Proposed Quantity") { }
        field(proposedDeliveryDate; Rec."Proposed Delivery Date") { }
        field(reasonCode; this.ReasonCode) { }
        field(reasonDescription; Rec."Reason Description") { }
        field(lastModifiedDateTime; Rec.SystemModifiedAt) { Editable = false; }
      }
    }
  }

  trigger OnNewRecord(BelowxRec: Boolean)
  begin
    this.InitializeInsert();
  end;

  trigger OnInsertRecord(BelowxRec: Boolean): Boolean
  begin
    this.InsertNestedLine();
    exit(false);
  end;

  trigger OnAfterGetRecord()
  begin
    this.LoadProjection();
  end;

  trigger OnModifyRecord(): Boolean
  begin
    this.RejectMutation();
  end;

  trigger OnDeleteRecord(): Boolean
  begin
    this.RejectMutation();
  end;

  local procedure InitializeInsert()
  begin
    Clear(this.ProposedItemNumber);
    Clear(this.ProposedVariantCode);
    Clear(this.ReasonCode);
  end;

  local procedure InsertNestedLine()
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    Rec."Proposed Item No." := this.ProposedItemNumber;
    Rec."Proposed Variant Code" := this.ProposedVariantCode;
    Rec."Reason Code" := this.ReasonCode;
    // A root POST has no proposal number; navigation POST targets a completed header.
    // Neither can pass the domain's pending-submission guard.
    ProposalMgt.InsertApiLine(Rec);
  end;

  local procedure LoadProjection()
  begin
    this.ProposedItemNumber := Rec."Proposed Item No.";
    this.ProposedVariantCode := Rec."Proposed Variant Code";
    this.ReasonCode := Rec."Reason Code";
  end;

  local procedure RejectMutation()
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    ProposalMgt.AssertApiWriteOnce();
  end;

  var
    ProposedItemNumber: Code[20];
    ProposedVariantCode: Code[10];
    ReasonCode: Code[10];
}
