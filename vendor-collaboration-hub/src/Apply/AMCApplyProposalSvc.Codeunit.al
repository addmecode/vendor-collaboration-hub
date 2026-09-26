namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50104 "AMC Apply Proposal Svc"
{
  TableNo = "AMC Vendor Proposal";
  Permissions = tabledata "Purchase Header" = M,
                tabledata "Purchase Line" = M;

  trigger OnRun()
  begin
    this.ApplyProposal(Rec);
  end;

  [CommitBehavior(CommitBehavior::Error)]
  local procedure ApplyProposal(DecisionContext: Record "AMC Vendor Proposal")
  var
    PurchaseHeader: Record "Purchase Header";
    VendorProposal: Record "AMC Vendor Proposal";
    VendorProposalLine: Record "AMC Vendor Proposal Line";
    VendorRequest: Record "AMC Vendor Request";
    CollabLog: Codeunit "AMC Collab Log";
    OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
    RequestMgt: Codeunit "AMC Request Mgt";
    ReleasePurchaseDocument: Codeunit "Release Purchase Document";
    PreviousPurchaseOrderNo: Code[20];
    PreviousRequestNo: Code[20];
  begin
    this.VerifyDecisionContext(DecisionContext);
    VendorProposal.LockTable();
    VendorProposal.Get(DecisionContext."No.");
    this.VerifyApprovalAllowed(VendorProposal);
    this.ApproveProposal(VendorProposal, DecisionContext);

    PurchaseHeader.SetLoadFields("Document Type", "No.", Status, "AMC Active Request No.");
    if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorProposal."Purchase Order No.") then
      Error(this.PurchaseOrderNotFoundErr, VendorProposal."Purchase Order No.");
    OrderLockMgt.AssertLockedBy(VendorProposal, PurchaseHeader);
    OrderLockMgt.SetSuppressionContext(PurchaseHeader."No.", VendorProposal."Request No.", PreviousPurchaseOrderNo, PreviousRequestNo);

    VendorProposalLine.SetCurrentKey("Proposal No.", "Sequence No.", "Line No.");
    VendorProposalLine.SetRange("Proposal No.", VendorProposal."No.");
    if VendorProposalLine.FindSet(true) then
      repeat
        this.ApplyLine(VendorProposal, VendorProposalLine, PurchaseHeader, CollabLog);
      until VendorProposalLine.Next() = 0;

    this.RecalculateRequestLines(VendorProposal."No.", VendorProposal."Request No.");
    ReleasePurchaseDocument.ReleasePurchaseHeader(PurchaseHeader, false);
    PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorProposal."Purchase Order No.");
    if PurchaseHeader.Status <> PurchaseHeader.Status::Released then
      Error(this.PurchaseOrderNotReleasedErr, PurchaseHeader."No.");
    VendorRequest.Get(VendorProposal."Request No.");
    RequestMgt.CloseAfterApply(VendorRequest, PurchaseHeader);
    this.SupersedeOtherOpenProposals(VendorProposal, ProposalMgt, CollabLog);
    VendorProposal."Applied Date Time" := CurrentDateTime();
    ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::Applied);
  end;

  local procedure VerifyDecisionContext(DecisionContext: Record "AMC Vendor Proposal")
  begin
    if (DecisionContext."No." = '') or
       (DecisionContext.Status <> DecisionContext.Status::Approved) or
       (DecisionContext."Decision User ID" <> UserId()) then
      Error(this.ProposalNotApprovedErr);
  end;

  local procedure VerifyApprovalAllowed(VendorProposal: Record "AMC Vendor Proposal")
  begin
    if not (VendorProposal.Status in [VendorProposal.Status::"In Review", VendorProposal.Status::"Apply Failed"]) then
      Error(this.ProposalNotApprovedErr);
  end;

  local procedure ApproveProposal(var VendorProposal: Record "AMC Vendor Proposal"; DecisionContext: Record "AMC Vendor Proposal")
  var
    CollabLog: Codeunit "AMC Collab Log";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    VendorProposal."Decision Date Time" := CurrentDateTime();
    VendorProposal."Decision User ID" := DecisionContext."Decision User ID";
    VendorProposal."Decision Reason" := DecisionContext."Decision Reason";
    VendorProposal."Apply Attempt Count" += 1;
    VendorProposal."Last Error Code" := '';
    VendorProposal."Last Error Message" := '';
    ProposalMgt.SetStatus(VendorProposal, VendorProposal.Status::Approved);
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalApproved, "AMC Actor Type"::Buyer, '', UserId(), false, this.ProposalApprovedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  local procedure ApplyLine(VendorProposal: Record "AMC Vendor Proposal"; var VendorProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header"; CollabLog: Codeunit "AMC Collab Log")
  var
    LineHandler: Interface "AMC IProposalLineHandler";
    OriginalPurchaseLine: Record "Purchase Line";
  begin
    this.GetOriginPurchaseLine(VendorProposal, VendorProposalLine, OriginalPurchaseLine);
    LineHandler := VendorProposalLine."Line Type";
    LineHandler.Apply(VendorProposalLine, PurchaseHeader);
    this.LogPurchaseLineChanges(VendorProposal, VendorProposalLine, OriginalPurchaseLine, CollabLog);
    this.LogInsertedPurchaseLines(VendorProposal, VendorProposalLine, OriginalPurchaseLine, CollabLog);
    this.LogAppliedLine(VendorProposal, VendorProposalLine, CollabLog);
    VendorProposalLine.Applied := true;
    VendorProposalLine."Applied Purchase Line No." := OriginalPurchaseLine."Line No.";
    VendorProposalLine.Modify(true);
  end;

  local procedure GetOriginPurchaseLine(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseLine: Record "Purchase Line")
  var
    VendorRequestLine: Record "AMC Vendor Request Line";
  begin
    VendorRequestLine.Get(VendorProposal."Request No.", VendorProposalLine."Request Line No.");
    PurchaseLine.Get(PurchaseLine."Document Type"::Order, VendorProposal."Purchase Order No.", VendorRequestLine."Purchase Line No.");
  end;

  local procedure LogPurchaseLineChanges(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; OriginalPurchaseLine: Record "Purchase Line"; CollabLog: Codeunit "AMC Collab Log")
  var
    UpdatedPurchaseLine: Record "Purchase Line";
  begin
    UpdatedPurchaseLine.Get(OriginalPurchaseLine."Document Type", OriginalPurchaseLine."Document No.", OriginalPurchaseLine."Line No.");
    if OriginalPurchaseLine.Quantity <> UpdatedPurchaseLine.Quantity then
      this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'Quantity', Format(OriginalPurchaseLine.Quantity), Format(UpdatedPurchaseLine.Quantity));
    if OriginalPurchaseLine."Promised Receipt Date" <> UpdatedPurchaseLine."Promised Receipt Date" then
      this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'Promised Receipt Date', Format(OriginalPurchaseLine."Promised Receipt Date"), Format(UpdatedPurchaseLine."Promised Receipt Date"));
    if OriginalPurchaseLine."AMC Vendor Confirmed" <> UpdatedPurchaseLine."AMC Vendor Confirmed" then
      this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'Vendor Confirmed', Format(OriginalPurchaseLine."AMC Vendor Confirmed"), Format(UpdatedPurchaseLine."AMC Vendor Confirmed"));
    this.LogPriceChanges(VendorProposal, VendorProposalLine, OriginalPurchaseLine, UpdatedPurchaseLine, CollabLog);
  end;

  local procedure LogInsertedPurchaseLines(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; OriginalPurchaseLine: Record "Purchase Line"; CollabLog: Codeunit "AMC Collab Log")
  var
    InsertedPurchaseLine: Record "Purchase Line";
  begin
    InsertedPurchaseLine.SetRange("Document Type", OriginalPurchaseLine."Document Type");
    InsertedPurchaseLine.SetRange("Document No.", OriginalPurchaseLine."Document No.");
    InsertedPurchaseLine.SetRange("AMC Origin Proposal No.", VendorProposal."No.");
    InsertedPurchaseLine.SetRange("AMC Origin Proposal Line No.", VendorProposalLine."Line No.");
    InsertedPurchaseLine.SetFilter("Line No.", '<>%1', OriginalPurchaseLine."Line No.");
    if InsertedPurchaseLine.FindSet() then
      repeat
        this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'Purchase Line No.', '', Format(InsertedPurchaseLine."Line No."));
        this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'No.', '', InsertedPurchaseLine."No.");
        this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'Quantity', '', Format(InsertedPurchaseLine.Quantity));
        this.LogAppliedField(VendorProposal, VendorProposalLine, CollabLog, 'Promised Receipt Date', '', Format(InsertedPurchaseLine."Promised Receipt Date"));
        if InsertedPurchaseLine."Direct Unit Cost" <> 0 then
          this.LogPriceRecalculated(VendorProposal, VendorProposalLine, CollabLog, 'Direct Unit Cost', '', Format(InsertedPurchaseLine."Direct Unit Cost"));
        if InsertedPurchaseLine."Line Discount %" <> 0 then
          this.LogPriceRecalculated(VendorProposal, VendorProposalLine, CollabLog, 'Line Discount %', '', Format(InsertedPurchaseLine."Line Discount %"));
      until InsertedPurchaseLine.Next() = 0;
  end;

  local procedure LogPriceChanges(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; PreviousPurchaseLine: Record "Purchase Line"; UpdatedPurchaseLine: Record "Purchase Line"; CollabLog: Codeunit "AMC Collab Log")
  begin
    if PreviousPurchaseLine."Direct Unit Cost" <> UpdatedPurchaseLine."Direct Unit Cost" then
      this.LogPriceRecalculated(VendorProposal, VendorProposalLine, CollabLog, 'Direct Unit Cost', Format(PreviousPurchaseLine."Direct Unit Cost"), Format(UpdatedPurchaseLine."Direct Unit Cost"));
    if PreviousPurchaseLine."Line Discount %" <> UpdatedPurchaseLine."Line Discount %" then
      this.LogPriceRecalculated(VendorProposal, VendorProposalLine, CollabLog, 'Line Discount %', Format(PreviousPurchaseLine."Line Discount %"), Format(UpdatedPurchaseLine."Line Discount %"));
  end;

  local procedure LogAppliedField(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; CollabLog: Codeunit "AMC Collab Log"; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250])
  begin
    CollabLog.LogFieldChange("AMC Source Type"::Proposal, VendorProposal."No.", VendorProposalLine."Line No.", "AMC Collab Entry Type"::ProposalApplied, "AMC Actor Type"::Buyer, '', UserId(), false, FieldName, OldValue, NewValue, this.ProposalAppliedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  local procedure LogAppliedLine(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; CollabLog: Codeunit "AMC Collab Log")
  begin
    CollabLog.LogEvent("AMC Source Type"::Proposal, VendorProposal."No.", VendorProposalLine."Line No.", "AMC Collab Entry Type"::ProposalApplied, "AMC Actor Type"::Buyer, '', UserId(), false, this.ProposalLineAppliedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  local procedure LogPriceRecalculated(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; CollabLog: Codeunit "AMC Collab Log"; FieldName: Text[80]; OldValue: Text[250]; NewValue: Text[250])
  begin
    CollabLog.LogFieldChange("AMC Source Type"::Proposal, VendorProposal."No.", VendorProposalLine."Line No.", "AMC Collab Entry Type"::PriceRecalculated, "AMC Actor Type"::Buyer, '', UserId(), false, FieldName, OldValue, NewValue, this.PriceRecalculatedDescriptionLbl, VendorProposal."Correlation Id");
  end;

  local procedure RecalculateRequestLines(ProposalNo: Code[20]; RequestNo: Code[20])
  var
    VendorProposalLine: Record "AMC Vendor Proposal Line";
    VendorRequestLine: Record "AMC Vendor Request Line";
    ConfirmedQuantity: Decimal;
  begin
    VendorRequestLine.SetRange("Request No.", RequestNo);
    if VendorRequestLine.FindSet(true) then
      repeat
        ConfirmedQuantity := this.GetConfirmedQuantity(ProposalNo, VendorRequestLine."Line No.", VendorProposalLine);
        if ConfirmedQuantity > VendorRequestLine."Requested Quantity" then
          ConfirmedQuantity := VendorRequestLine."Requested Quantity";
        VendorRequestLine."Confirmed Quantity" := ConfirmedQuantity;
        VendorRequestLine."Outstanding Quantity" := VendorRequestLine."Requested Quantity" - ConfirmedQuantity;
        if VendorRequestLine."Outstanding Quantity" <= 0 then
          VendorRequestLine.Status := VendorRequestLine.Status::Confirmed
        else
          if ConfirmedQuantity > 0 then
            VendorRequestLine.Status := VendorRequestLine.Status::"Partially Confirmed"
          else
            VendorRequestLine.Status := VendorRequestLine.Status::Open;
        VendorRequestLine.Modify(true);
      until VendorRequestLine.Next() = 0;
  end;

  local procedure GetConfirmedQuantity(ProposalNo: Code[20]; RequestLineNo: Integer; var VendorProposalLine: Record "AMC Vendor Proposal Line"): Decimal
  var
    ConfirmedQuantity: Decimal;
  begin
    VendorProposalLine.Reset();
    VendorProposalLine.SetRange("Proposal No.", ProposalNo);
    VendorProposalLine.SetRange("Request Line No.", RequestLineNo);
    if VendorProposalLine.FindSet() then
      repeat
        ConfirmedQuantity += VendorProposalLine."Proposed Quantity";
      until VendorProposalLine.Next() = 0;
    exit(ConfirmedQuantity);
  end;

  local procedure SupersedeOtherOpenProposals(VendorProposal: Record "AMC Vendor Proposal"; ProposalMgt: Codeunit "AMC Proposal Mgt"; CollabLog: Codeunit "AMC Collab Log")
  var
    OtherVendorProposal: Record "AMC Vendor Proposal";
    ProposalSupersededDescriptionLbl: Label 'Vendor proposal superseded because another proposal was applied.';
  begin
    OtherVendorProposal.SetRange("Purchase Order No.", VendorProposal."Purchase Order No.");
    OtherVendorProposal.SetFilter(Status, '%1|%2', OtherVendorProposal.Status::Submitted, OtherVendorProposal.Status::"In Review");
    if OtherVendorProposal.FindSet(true) then
      repeat
        if OtherVendorProposal."No." <> VendorProposal."No." then begin
          ProposalMgt.SetStatus(OtherVendorProposal, OtherVendorProposal.Status::Superseded);
          CollabLog.LogEvent("AMC Source Type"::Proposal, OtherVendorProposal."No.", 0, "AMC Collab Entry Type"::ProposalSuperseded, "AMC Actor Type"::Buyer, '', UserId(), false, ProposalSupersededDescriptionLbl, OtherVendorProposal."Correlation Id");
        end;
      until OtherVendorProposal.Next() = 0;
  end;

  var
    ProposalNotApprovedErr: Label 'VCH-APL-0001: Vendor proposal must be approved before it can be applied.';
    PurchaseOrderNotFoundErr: Label 'VCH-APL-0002: Purchase order %1 does not exist.', Comment = '%1 = purchase order number';
    PurchaseOrderNotReleasedErr: Label 'Purchase order %1 could not be released.', Comment = '%1 = purchase order number';
    ProposalApprovedDescriptionLbl: Label 'Vendor proposal approved.';
    ProposalAppliedDescriptionLbl: Label 'Vendor proposal field applied.';
    ProposalLineAppliedDescriptionLbl: Label 'Vendor proposal line applied.';
    PriceRecalculatedDescriptionLbl: Label 'Purchase price recalculated after applying vendor proposal.';
}
