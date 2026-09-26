namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.AuditCodes;
using Microsoft.Inventory.Item.Substitution;

codeunit 50102 "AMC Proposal Validator"
{
  procedure Validate(VendorProposal: Record "AMC Vendor Proposal"; var Result: Codeunit "AMC Validation Result")
  var
    CollaborationSetup: Record "AMC Collaboration Setup";
    VendorRequest: Record "AMC Vendor Request";
  begin
    if not VendorRequest.Get(VendorProposal."Request No.") then begin
      this.AddRequestError(Result, this.RequestNotOpenCodeLbl, this.RequestNotFoundErr);
      exit;
    end;

    if (VendorRequest."Vendor No." <> VendorProposal."Vendor No.") or
     (VendorRequest.Status in [VendorRequest.Status::Closed, VendorRequest.Status::Cancelled]) then begin
      this.AddRequestError(Result, this.RequestNotOpenCodeLbl, this.RequestNotOpenErr);
      exit;
    end;

    if not CollaborationSetup.Get() then begin
      this.AddRequestError(Result, this.RequestNotOpenCodeLbl, this.SetupNotFoundErr);
      exit;
    end;

    this.ValidateLines(VendorProposal, CollaborationSetup, Result);
  end;

  local procedure ValidateLines(VendorProposal: Record "AMC Vendor Proposal"; CollaborationSetup: Record "AMC Collaboration Setup"; var Result: Codeunit "AMC Validation Result")
  var
    VendorProposalLine: Record "AMC Vendor Proposal Line";
    SplitCounts: Dictionary of [Integer, Integer];
    SplitQuantities: Dictionary of [Integer, Decimal];
  begin
    VendorProposalLine.SetRange("Proposal No.", VendorProposal."No.");
    if VendorProposalLine.FindSet() then
      repeat
        this.ValidateLine(VendorProposal, VendorProposalLine, CollaborationSetup, SplitCounts, SplitQuantities, Result);
      until VendorProposalLine.Next() = 0;
  end;

  local procedure ValidateLine(VendorProposal: Record "AMC Vendor Proposal"; VendorProposalLine: Record "AMC Vendor Proposal Line"; CollaborationSetup: Record "AMC Collaboration Setup"; var SplitCounts: Dictionary of [Integer, Integer]; var SplitQuantities: Dictionary of [Integer, Decimal]; var Result: Codeunit "AMC Validation Result")
  var
    LineHandler: Interface "AMC IProposalLineHandler";
    VendorRequestLine: Record "AMC Vendor Request Line";
  begin
    if not VendorRequestLine.Get(VendorProposal."Request No.", VendorProposalLine."Request Line No.") then begin
      this.AddLineError(Result, this.RequestLineNotFoundCodeLbl, VendorProposalLine, this.RequestLineNotFoundErr);
      exit;
    end;

    if (VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Change Quantity") and
     (VendorProposalLine."Proposed Quantity" <= 0) then
      this.AddLineError(Result, this.QuantityMustBePositiveCodeLbl, VendorProposalLine, this.QuantityMustBePositiveErr);

    if (VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Split Delivery") and
     (VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Change Quantity") and
     (VendorProposalLine."Proposed Quantity" > VendorRequestLine."Outstanding Quantity") then
      this.AddLineError(Result, this.QuantityExceedsOutstandingCodeLbl, VendorProposalLine,
        StrSubstNo(this.QuantityExceedsOutstandingErr, VendorProposalLine."Proposed Quantity", VendorRequestLine."Outstanding Quantity", VendorRequestLine."Line No."));

    if (VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Change Date") and
       (VendorProposalLine."Proposed Delivery Date" < WorkDate()) then
      this.AddLineError(Result, this.DeliveryDateInPastCodeLbl, VendorProposalLine, this.DeliveryDateInPastErr);

    this.ValidateReasonCode(VendorProposalLine, CollaborationSetup, Result);
    this.ValidateSplitCount(VendorProposalLine, CollaborationSetup, SplitCounts, Result);
    this.ValidateSplitQuantity(VendorProposalLine, VendorRequestLine, SplitQuantities, Result);
    this.ValidateSubstitution(VendorProposalLine, VendorRequestLine, CollaborationSetup, Result);
    LineHandler := VendorProposalLine."Line Type";
    LineHandler.Validate(VendorProposalLine, VendorRequestLine, Result);
  end;

  local procedure ValidateReasonCode(VendorProposalLine: Record "AMC Vendor Proposal Line"; CollaborationSetup: Record "AMC Collaboration Setup"; var Result: Codeunit "AMC Validation Result")
  var
    ReasonCode: Record "Reason Code";
  begin
    if CollaborationSetup."Require Reason Code" and
     (VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::Confirm) and
     (VendorProposalLine."Reason Code" = '') then begin
      this.AddLineError(Result, this.ReasonCodeRequiredCodeLbl, VendorProposalLine, this.ReasonCodeRequiredErr);
      exit;
    end;

    if (VendorProposalLine."Reason Code" <> '') and not ReasonCode.Get(VendorProposalLine."Reason Code") then
      this.AddLineError(Result, this.ReasonCodeRequiredCodeLbl, VendorProposalLine,
        StrSubstNo(this.ReasonCodeNotFoundErr, VendorProposalLine."Reason Code"));
  end;

  local procedure ValidateSplitCount(VendorProposalLine: Record "AMC Vendor Proposal Line"; CollaborationSetup: Record "AMC Collaboration Setup"; var SplitCounts: Dictionary of [Integer, Integer]; var Result: Codeunit "AMC Validation Result")
  var
    SplitCount: Integer;
  begin
    if VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Split Delivery" then
      exit;

    if not SplitCounts.Get(VendorProposalLine."Request Line No.", SplitCount) then
      SplitCount := 0;
    SplitCount += 1;
    SplitCounts.Set(VendorProposalLine."Request Line No.", SplitCount);

    if SplitCount > CollaborationSetup."Max Splits per Line" then
      this.AddLineError(Result, this.TooManySplitsCodeLbl, VendorProposalLine,
        StrSubstNo(this.TooManySplitsErr, CollaborationSetup."Max Splits per Line"));
  end;

  local procedure ValidateSplitQuantity(VendorProposalLine: Record "AMC Vendor Proposal Line"; VendorRequestLine: Record "AMC Vendor Request Line"; var SplitQuantities: Dictionary of [Integer, Decimal]; var Result: Codeunit "AMC Validation Result")
  var
    SplitQuantity: Decimal;
  begin
    if VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Split Delivery" then
      exit;

    if not SplitQuantities.Get(VendorProposalLine."Request Line No.", SplitQuantity) then
      SplitQuantity := 0;
    SplitQuantity += VendorProposalLine."Proposed Quantity";
    SplitQuantities.Set(VendorProposalLine."Request Line No.", SplitQuantity);

    if SplitQuantity > VendorRequestLine."Outstanding Quantity" then
      this.AddLineError(Result, this.QuantityExceedsOutstandingCodeLbl, VendorProposalLine,
        StrSubstNo(this.QuantityExceedsOutstandingErr, SplitQuantity, VendorRequestLine."Outstanding Quantity", VendorRequestLine."Line No."));
  end;

  local procedure ValidateSubstitution(VendorProposalLine: Record "AMC Vendor Proposal Line"; VendorRequestLine: Record "AMC Vendor Request Line"; CollaborationSetup: Record "AMC Collaboration Setup"; var Result: Codeunit "AMC Validation Result")
  var
    ItemSubstitution: Record "Item Substitution";
  begin
    if VendorProposalLine."Line Type" <> VendorProposalLine."Line Type"::"Substitute Item" then
      exit;

    if not CollaborationSetup."Allow Item Substitution" then begin
      this.AddLineError(Result, this.ItemSubstitutionCodeLbl, VendorProposalLine, this.ItemSubstitutionNotAllowedErr);
      exit;
    end;

    ItemSubstitution.SetRange("No.", VendorRequestLine."Item No.");
    ItemSubstitution.SetRange("Variant Code", VendorRequestLine."Variant Code");
    ItemSubstitution.SetRange("Substitute No.", VendorProposalLine."Proposed Item No.");
    ItemSubstitution.SetRange("Substitute Variant Code", VendorProposalLine."Proposed Variant Code");
    if ItemSubstitution.IsEmpty() then
      this.AddLineError(Result, this.ItemSubstitutionCodeLbl, VendorProposalLine,
        StrSubstNo(this.ItemSubstitutionNotRegisteredErr, VendorProposalLine."Proposed Item No.", VendorRequestLine."Item No."));
  end;

  local procedure AddRequestError(var Result: Codeunit "AMC Validation Result"; ErrorCode: Code[20]; ErrorText: Text)
  begin
    Result.AddError(ErrorCode, 0, 0, ErrorText);
  end;

  local procedure AddLineError(var Result: Codeunit "AMC Validation Result"; ErrorCode: Code[20]; VendorProposalLine: Record "AMC Vendor Proposal Line"; ErrorText: Text)
  begin
    Result.AddError(ErrorCode, VendorProposalLine."Request Line No.", VendorProposalLine."Sequence No.", ErrorText);
  end;

  var
    RequestNotOpenCodeLbl: Label 'VCH-VAL-0001', Locked = true;
    RequestLineNotFoundCodeLbl: Label 'VCH-VAL-0002', Locked = true;
    QuantityMustBePositiveCodeLbl: Label 'VCH-VAL-0010', Locked = true;
    QuantityExceedsOutstandingCodeLbl: Label 'VCH-VAL-0012', Locked = true;
    DeliveryDateInPastCodeLbl: Label 'VCH-VAL-0020', Locked = true;
    ItemSubstitutionCodeLbl: Label 'VCH-VAL-0030', Locked = true;
    TooManySplitsCodeLbl: Label 'VCH-VAL-0031', Locked = true;
    ReasonCodeRequiredCodeLbl: Label 'VCH-VAL-0040', Locked = true;
    RequestNotFoundErr: Label 'The vendor request does not exist.';
    RequestNotOpenErr: Label 'The vendor request is not active for this vendor proposal.';
    SetupNotFoundErr: Label 'Vendor collaboration setup must be completed before validating a proposal.';
    RequestLineNotFoundErr: Label 'The request line does not exist.';
    QuantityMustBePositiveErr: Label 'Proposed quantity must be positive.';
    QuantityExceedsOutstandingErr: Label 'Proposed quantity %1 exceeds outstanding quantity %2 on request line %3.', Comment = '%1 = proposed quantity, %2 = outstanding quantity, %3 = request line number';
    DeliveryDateInPastErr: Label 'Proposed delivery date cannot be before the work date.';
    ItemSubstitutionNotAllowedErr: Label 'Item substitution is not allowed by vendor collaboration setup.';
    ItemSubstitutionNotRegisteredErr: Label 'Item %1 is not a registered substitute for item %2.', Comment = '%1 = proposed substitute item number, %2 = requested item number';
    TooManySplitsErr: Label 'The proposal exceeds the maximum of %1 splits per request line.', Comment = '%1 = maximum splits per line';
    ReasonCodeRequiredErr: Label 'A reason code is required.';
    ReasonCodeNotFoundErr: Label 'Reason code %1 does not exist.', Comment = '%1 = reason code';
}
