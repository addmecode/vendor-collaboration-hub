namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50123 "AMC Purchase Line Builder"
{
  procedure Build(OriginPurchaseLine: Record "Purchase Line"; ProposalLine: Record "AMC Vendor Proposal Line"; ItemNo: Code[20]; VariantCode: Code[10]; NewQuantity: Decimal; PromisedReceiptDate: Date; var NewPurchaseLine: Record "Purchase Line")
  var
    NextPurchaseLine: Record "Purchase Line";
  begin
    NewPurchaseLine.Init();
    NewPurchaseLine.Validate("Document Type", OriginPurchaseLine."Document Type");
    NewPurchaseLine.Validate("Document No.", OriginPurchaseLine."Document No.");
    NewPurchaseLine.Validate("Line No.", this.GetLineNoAfterOrigin(OriginPurchaseLine, NextPurchaseLine));
    NewPurchaseLine.Validate("Buy-from Vendor No.", OriginPurchaseLine."Buy-from Vendor No.");
    NewPurchaseLine.Validate("Pay-to Vendor No.", OriginPurchaseLine."Pay-to Vendor No.");
    NewPurchaseLine.Validate(Type, OriginPurchaseLine.Type);
    NewPurchaseLine.Validate("No.", ItemNo);
    NewPurchaseLine.Validate("Variant Code", VariantCode);
    NewPurchaseLine.Validate("Location Code", OriginPurchaseLine."Location Code");
    NewPurchaseLine.Validate("Unit of Measure Code", OriginPurchaseLine."Unit of Measure Code");
    NewPurchaseLine.Validate("Shortcut Dimension 1 Code", OriginPurchaseLine."Shortcut Dimension 1 Code");
    NewPurchaseLine.Validate("Shortcut Dimension 2 Code", OriginPurchaseLine."Shortcut Dimension 2 Code");
    NewPurchaseLine.Validate("Dimension Set ID", OriginPurchaseLine."Dimension Set ID");
    NewPurchaseLine.Validate(Quantity, NewQuantity);
    NewPurchaseLine.Validate("Requested Receipt Date", OriginPurchaseLine."Requested Receipt Date");
    NewPurchaseLine.Validate("Promised Receipt Date", PromisedReceiptDate);
    NewPurchaseLine.Validate("AMC Origin Proposal No.", ProposalLine."Proposal No.");
    NewPurchaseLine.Validate("AMC Origin Proposal Line No.", ProposalLine."Line No.");
    NewPurchaseLine.Insert(true);
  end;

  local procedure GetLineNoAfterOrigin(OriginPurchaseLine: Record "Purchase Line"; var NextPurchaseLine: Record "Purchase Line"): Integer
  var
    NextLineNo: Integer;
  begin
    NextPurchaseLine.SetRange("Document Type", OriginPurchaseLine."Document Type");
    NextPurchaseLine.SetRange("Document No.", OriginPurchaseLine."Document No.");
    NextPurchaseLine.SetFilter("Line No.", '>%1', OriginPurchaseLine."Line No.");
    if NextPurchaseLine.FindFirst() then
      NextLineNo := NextPurchaseLine."Line No."
    else
      NextLineNo := OriginPurchaseLine."Line No." + 10000;

    if NextLineNo - OriginPurchaseLine."Line No." <= 1 then
      Error(this.NoLineGapAfterOriginErr, OriginPurchaseLine."Line No.");

    exit(OriginPurchaseLine."Line No." + ((NextLineNo - OriginPurchaseLine."Line No.") div 2));
  end;

  var
    NoLineGapAfterOriginErr: Label 'VCH-APL-0005: No free purchase line number is available after origin line %1.', Comment = '%1 = origin purchase line number';
}
