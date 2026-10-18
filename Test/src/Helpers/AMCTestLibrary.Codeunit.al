namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.AuditCodes;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Purchases.Vendor;

codeunit 50149 "AMC Test Library"
{
  procedure CreateWriteContext(var VendorRequest: Record "AMC Vendor Request"; var AccessToken: Record "AMC Vendor Access Token")
  var
    Vendor: Record Vendor;
    Setup: Record "AMC Collaboration Setup";
    NoSeries: Record "No. Series";
    NoSeriesLine: Record "No. Series Line";
    AccessTokenMgt: Codeunit "AMC Access Token Mgt";
  begin
    // These pure API fixtures do not send email, apply purchasing changes or use HTTP.
    Vendor.Init();
    Vendor."No." := this.NewCode();
    Vendor."AMC Collaboration Enabled" := true;
    Vendor.Insert(false);
    NoSeries.Init();
    NoSeries.Code := this.NewCode();
    NoSeries."Default Nos." := true;
    NoSeries.Insert(false);
    NoSeriesLine.Init();
    NoSeriesLine."Series Code" := NoSeries.Code;
    NoSeriesLine."Line No." := 10000;
    NoSeriesLine."Starting No." := CopyStr(NoSeries.Code, 1, 10) + '-000001';
    NoSeriesLine."Increment-by No." := 1;
    NoSeriesLine.Insert(false);
    if not Setup.Get() then begin
      Setup.Init();
      Setup.Insert(false);
    end;
    Setup.Enabled := true;
    Setup."Proposal Nos." := NoSeries.Code;
    Setup."Allow Item Substitution" := true;
    Setup."Max Splits per Line" := 2;
    Setup."Require Reason Code" := true;
    Setup.Modify(false);
    VendorRequest.Init();
    VendorRequest."No." := this.NewCode();
    VendorRequest."Vendor No." := Vendor."No.";
    VendorRequest."Purchase Order No." := 'PO-10482';
    VendorRequest.Status := VendorRequest.Status::"Awaiting Vendor";
    VendorRequest.Insert(false);
    this.CreateRequestLine(VendorRequest."No.", 10000, 'ITEM-A', 1000);
    this.CreateRequestLine(VendorRequest."No.", 20000, 'ITEM-B', 500);
    this.EnsureReason('CAPACITY');
    this.EnsureReason('UNAVAIL');
    this.EnsureSubstitution();
    AccessToken.Init();
    AccessToken."Token Id" := CreateGuid();
    AccessToken."Request No." := VendorRequest."No.";
    AccessToken."Vendor No." := Vendor."No.";
    AccessToken."Token Hash" := AccessTokenMgt.HashToken(Format(CreateGuid()));
    AccessToken.Status := AccessToken.Status::Active;
    AccessToken."Expires At" := CurrentDateTime() + 3600000;
    AccessToken.Insert(false);
  end;

  procedure SubmitAnswer(VendorRequest: Record "AMC Vendor Request"; AccessTokenId: Guid; IdempotencyKey: Text[64]; SecondSplitQuantity: Decimal; ReverseLines: Boolean; var VendorProposal: Record "AMC Vendor Proposal")
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    VendorProposal.Reset();
    VendorProposal.Init();
    Clear(VendorProposal.SystemId);
    VendorProposal."Request No." := VendorRequest."No.";
    VendorProposal."Vendor No." := VendorRequest."Vendor No.";
    VendorProposal."Submitted By" := 'anna.k@example.com';
    VendorProposal."External Reference" := 'CC-ACK-55821';
    ProposalMgt.BeginApiSubmission(VendorProposal, AccessTokenId, IdempotencyKey);
    if ReverseLines then begin
      this.AddAnswerLine(VendorProposal, 20000, 1, "AMC Proposal Line Type"::"Substitute Item", 500);
      this.AddAnswerLine(VendorProposal, 10000, 2, "AMC Proposal Line Type"::"Split Delivery", SecondSplitQuantity);
      this.AddAnswerLine(VendorProposal, 10000, 1, "AMC Proposal Line Type"::"Split Delivery", 600);
    end else begin
      this.AddAnswerLine(VendorProposal, 10000, 1, "AMC Proposal Line Type"::"Split Delivery", 600);
      this.AddAnswerLine(VendorProposal, 10000, 2, "AMC Proposal Line Type"::"Split Delivery", SecondSplitQuantity);
      this.AddAnswerLine(VendorProposal, 20000, 1, "AMC Proposal Line Type"::"Substitute Item", 500);
    end;
    ProposalMgt.CompleteApiSubmission(VendorProposal, AccessTokenId, IdempotencyKey);
  end;

  procedure AddAnswerLine(VendorProposal: Record "AMC Vendor Proposal"; RequestLineNo: Integer; SequenceNo: Integer; LineType: Enum "AMC Proposal Line Type"; Quantity: Decimal)
  var
    ProposalLine: Record "AMC Vendor Proposal Line";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    ProposalLine.Init();
    ProposalLine."Proposal No." := VendorProposal."No.";
    ProposalLine."Request Line No." := RequestLineNo;
    ProposalLine."Sequence No." := SequenceNo;
    ProposalLine."Line Type" := LineType;
    ProposalLine."Proposed Quantity" := Quantity;
    ProposalLine."Proposed Delivery Date" := WorkDate() + SequenceNo;
    ProposalLine."Reason Code" := 'CAPACITY';
    ProposalLine."Reason Description" := 'Production capacity limitation';
    if LineType = LineType::"Substitute Item" then begin
      ProposalLine."Proposed Item No." := 'ITEM-B2';
      ProposalLine."Reason Code" := 'UNAVAIL';
      ProposalLine."Reason Description" := 'Original item temporarily unavailable';
    end;
    ProposalMgt.InsertApiLine(ProposalLine);
  end;

  procedure NewCode(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;

  local procedure CreateRequestLine(RequestNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; Quantity: Decimal)
  var
    RequestLine: Record "AMC Vendor Request Line";
  begin
    RequestLine.Init();
    RequestLine."Request No." := RequestNo;
    RequestLine."Line No." := LineNo;
    RequestLine."Purchase Line No." := LineNo;
    RequestLine."Item No." := ItemNo;
    RequestLine."Requested Quantity" := Quantity;
    RequestLine."Outstanding Quantity" := Quantity;
    RequestLine."Requested Delivery Date" := WorkDate() + 1;
    RequestLine.Insert(false);
  end;

  local procedure EnsureReason(Reason: Code[10])
  var
    ReasonCode: Record "Reason Code";
  begin
    if ReasonCode.Get(Reason) then
      exit;
    ReasonCode.Init();
    ReasonCode.Code := Reason;
    ReasonCode.Insert(false);
  end;

  local procedure EnsureSubstitution()
  var
    ItemSubstitution: Record "Item Substitution";
  begin
    ItemSubstitution.SetRange("No.", 'ITEM-B');
    ItemSubstitution.SetRange("Variant Code", '');
    ItemSubstitution.SetRange("Substitute No.", 'ITEM-B2');
    ItemSubstitution.SetRange("Substitute Variant Code", '');
    if not ItemSubstitution.IsEmpty() then
      exit;
    ItemSubstitution.Init();
    ItemSubstitution."No." := 'ITEM-B';
    ItemSubstitution."Substitute No." := 'ITEM-B2';
    ItemSubstitution.Insert(false);
  end;
}
