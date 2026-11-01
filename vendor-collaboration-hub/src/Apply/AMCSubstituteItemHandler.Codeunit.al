namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50115 "AMC Substitute Item Handler" implements "AMC IProposalLineHandler"
{
  Permissions = tabledata "AMC Vendor Proposal" = r,
                tabledata "AMC Vendor Request Line" = r,
                tabledata "Purchase Line" = rm;

  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result")
  begin
  end;

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header")
  var
    NewPurchaseLine: Record "Purchase Line";
    OriginPurchaseLine: Record "Purchase Line";
    RequestLine: Record "AMC Vendor Request Line";
    PurchaseLineBuilder: Codeunit "AMC Purchase Line Builder";
  begin
    this.GetRequestLine(ProposalLine, RequestLine);
    if not OriginPurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", RequestLine."Purchase Line No.") then
      Error(this.RequiredRecordNotFoundErr, OriginPurchaseLine.TableCaption());
    PurchaseLineBuilder.Build(OriginPurchaseLine, ProposalLine, ProposalLine."Proposed Item No.", ProposalLine."Proposed Variant Code", ProposalLine."Proposed Quantity", ProposalLine."Proposed Delivery Date", NewPurchaseLine);

    OriginPurchaseLine.Validate(Quantity, OriginPurchaseLine.Quantity - ProposalLine."Proposed Quantity");
    OriginPurchaseLine.Validate("AMC Origin Proposal No.", ProposalLine."Proposal No.");
    OriginPurchaseLine.Validate("AMC Origin Proposal Line No.", ProposalLine."Line No.");
    OriginPurchaseLine.Modify(true);
  end;

  local procedure GetRequestLine(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line")
  var
    VendorProposal: Record "AMC Vendor Proposal";
  begin
    if not VendorProposal.Get(ProposalLine."Proposal No.") then
      Error(this.RequiredRecordNotFoundErr, VendorProposal.TableCaption());
    if not RequestLine.Get(VendorProposal."Request No.", ProposalLine."Request Line No.") then
      Error(this.RequiredRecordNotFoundErr, RequestLine.TableCaption());
  end;

  var
    RequiredRecordNotFoundErr: Label 'VCH-DAT-0001: The %1 record required to process the proposal could not be found.', Comment = '%1 = table caption';
}
