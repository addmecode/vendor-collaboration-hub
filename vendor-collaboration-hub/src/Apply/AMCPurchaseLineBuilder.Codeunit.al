namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50123 "AMC Purchase Line Builder"
{
    procedure Build(OriginPurchaseLine: Record "Purchase Line"; ProposalLine: Record "AMC Vendor Proposal Line"; var NewPurchaseLine: Record "Purchase Line")
    var
        NextPurchaseLine: Record "Purchase Line";
    begin
        NewPurchaseLine.Init();
        NewPurchaseLine."Document Type" := OriginPurchaseLine."Document Type";
        NewPurchaseLine."Document No." := OriginPurchaseLine."Document No.";
        NewPurchaseLine."Line No." := this.GetLineNoAfterOrigin(OriginPurchaseLine, NextPurchaseLine);
        NewPurchaseLine.Validate(Type, OriginPurchaseLine.Type);
        NewPurchaseLine.Validate("No.", OriginPurchaseLine."No.");
        NewPurchaseLine.Validate("Variant Code", OriginPurchaseLine."Variant Code");
        NewPurchaseLine.Validate("Location Code", OriginPurchaseLine."Location Code");
        NewPurchaseLine.Validate("Unit of Measure Code", OriginPurchaseLine."Unit of Measure Code");
        NewPurchaseLine.Validate("Shortcut Dimension 1 Code", OriginPurchaseLine."Shortcut Dimension 1 Code");
        NewPurchaseLine.Validate("Shortcut Dimension 2 Code", OriginPurchaseLine."Shortcut Dimension 2 Code");
        NewPurchaseLine."Dimension Set ID" := OriginPurchaseLine."Dimension Set ID";
        NewPurchaseLine.Validate(Quantity, OriginPurchaseLine.Quantity);
        NewPurchaseLine.Validate("Requested Receipt Date", OriginPurchaseLine."Requested Receipt Date");
        NewPurchaseLine.Validate("Promised Receipt Date", OriginPurchaseLine."Promised Receipt Date");
        NewPurchaseLine.Validate("AMC Origin Proposal No.", ProposalLine."Proposal No.");
        NewPurchaseLine.Validate("AMC Origin Proposal Line No.", ProposalLine."Line No.");
        NewPurchaseLine.Insert(true);
    end;

    local procedure GetLineNoAfterOrigin(OriginPurchaseLine: Record "Purchase Line"; var NextPurchaseLine: Record "Purchase Line"): Integer
    var
        NewLineNo: Integer;
    begin
        NextPurchaseLine.SetRange("Document Type", OriginPurchaseLine."Document Type");
        NextPurchaseLine.SetRange("Document No.", OriginPurchaseLine."Document No.");
        NextPurchaseLine.SetFilter("Line No.", '>%1', OriginPurchaseLine."Line No.");
        if NextPurchaseLine.FindFirst() then begin
            if NextPurchaseLine."Line No." - OriginPurchaseLine."Line No." <= 1 then
                Error(this.NoLineGapAfterOriginErr, OriginPurchaseLine."Line No.");
            exit(OriginPurchaseLine."Line No." + ((NextPurchaseLine."Line No." - OriginPurchaseLine."Line No.") div 2));
        end;

        NewLineNo := OriginPurchaseLine."Line No." + 10000;
        exit(NewLineNo);
    end;

    var
        NoLineGapAfterOriginErr: Label 'No free purchase line number is available after origin line %1.', Comment = '%1 = origin purchase line number';
}
