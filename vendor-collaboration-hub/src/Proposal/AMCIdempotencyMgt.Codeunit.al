namespace Addmecode.VendorCollaborationHub;

using System.Security.Encryption;

codeunit 50121 "AMC Idempotency Mgt"
{
  Permissions = tabledata "AMC Vendor Proposal" = r,
                tabledata "AMC Vendor Proposal Line" = r;

  procedure Register(var VendorProposal: Record "AMC Vendor Proposal"; IdempotencyKey: Text[64]; PayloadHash: Text[64])
  var
    ExistingProposal: Record "AMC Vendor Proposal";
    DuplicateErr: Label 'VCH-IDM-0000: Duplicate request, existing proposal id = %1, number = %2.', Comment = '%1 = existing proposal SystemId, %2 = existing proposal number';
    DifferentPayloadErr: Label 'VCH-IDM-0001: The idempotency key is already used with a different payload.';
    KeyRequiredErr: Label 'VCH-IDM-0002: An idempotency key is required.';
  begin
    if IdempotencyKey = '' then
      Error(KeyRequiredErr);

    // Keep the duplicate check and the unique-index write in the caller's transaction.
    ExistingProposal.LockTable();
    ExistingProposal.SetLoadFields("Payload Hash", SystemId, "No.");
    ExistingProposal.SetRange("Vendor No.", VendorProposal."Vendor No.");
    ExistingProposal.SetRange("Idempotency Key", IdempotencyKey);
    if ExistingProposal.FindFirst() then begin
      if ExistingProposal."Payload Hash" = PayloadHash then
        Error(DuplicateErr, Format(ExistingProposal.SystemId, 0, 4), ExistingProposal."No.");
      Error(DifferentPayloadErr);
    end;

    VendorProposal."Idempotency Key" := IdempotencyKey;
    VendorProposal."Payload Hash" := PayloadHash;
  end;

  procedure HashPayload(VendorProposal: Record "AMC Vendor Proposal"; AccessTokenId: Guid): Text[64]
  var
    ProposalLine: Record "AMC Vendor Proposal Line";
    CryptographyManagement: Codeunit "Cryptography Management";
    Payload: JsonObject;
    Lines: JsonArray;
    Line: JsonObject;
    PayloadText: Text;
    HashAlgorithmType: Option MD5,SHA1,SHA256,SHA384,SHA512;
  begin
    // Fixed property order, typed JSON scalars and business-line ordering are independent
    // of JSON input order, locale, generated numbers/SystemIds and tracing metadata.
    Payload.Add('version', 1);
    Payload.Add('requestNumber', VendorProposal."Request No.");
    Payload.Add('vendorNumber', VendorProposal."Vendor No.");
    Payload.Add('accessTokenId', LowerCase(Format(AccessTokenId, 0, 4)));
    Payload.Add('submittedBy', VendorProposal."Submitted By");
    Payload.Add('externalReference', VendorProposal."External Reference");
    ProposalLine.SetCurrentKey("Proposal No.", "Request Line No.", "Sequence No.");
    ProposalLine.SetRange("Proposal No.", VendorProposal."No.");
    ProposalLine.SetLoadFields("Request Line No.", "Sequence No.", "Line Type", "Proposed Item No.", "Proposed Variant Code", "Proposed Quantity", "Proposed Delivery Date", "Reason Code", "Reason Description");
    if ProposalLine.FindSet() then
      repeat
        Clear(Line);
        Line.Add('requestLineNumber', ProposalLine."Request Line No.");
        Line.Add('sequenceNumber', ProposalLine."Sequence No.");
        Line.Add('lineType', ProposalLine."Line Type".AsInteger());
        Line.Add('proposedItemNumber', ProposalLine."Proposed Item No.");
        Line.Add('proposedVariantCode', ProposalLine."Proposed Variant Code");
        Line.Add('proposedQuantity', ProposalLine."Proposed Quantity");
        Line.Add('proposedDeliveryDate', Format(ProposalLine."Proposed Delivery Date", 0, 9));
        Line.Add('reasonCode', ProposalLine."Reason Code");
        Line.Add('reasonDescription', ProposalLine."Reason Description");
        Lines.Add(Line);
      until ProposalLine.Next() = 0;
    Payload.Add('vendorProposalLines', Lines);
    Payload.WriteTo(PayloadText);
    exit(UpperCase(CryptographyManagement.GenerateHash(PayloadText, HashAlgorithmType::SHA256)));
  end;
}
