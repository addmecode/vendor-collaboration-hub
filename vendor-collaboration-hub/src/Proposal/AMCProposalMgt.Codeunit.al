namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;

codeunit 50101 "AMC Proposal Mgt"
{
    procedure CreateDraftFromRequest(VendorRequest: Record "AMC Vendor Request"): Code[20]
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        VendorProposal: Record "AMC Vendor Proposal";
        NoSeries: Codeunit "No. Series";
        ProposalNo: Code[20];
        ManualIdempotencyKeyLbl: Label 'MANUAL-%1', Locked = true;
    begin
        VendorRequest.Get(VendorRequest."No.");
        CollaborationSetup.GetSetup();

        ProposalNo := NoSeries.GetNextNo(CollaborationSetup."Proposal Nos.");
        VendorProposal.Init();
        VendorProposal."No." := ProposalNo;
        VendorProposal."Request No." := VendorRequest."No.";
        VendorProposal."Vendor No." := VendorRequest."Vendor No.";
        VendorProposal."Purchase Order No." := VendorRequest."Purchase Order No.";
        VendorProposal."Idempotency Key" := CopyStr(StrSubstNo(ManualIdempotencyKeyLbl, ProposalNo), 1, MaxStrLen(VendorProposal."Idempotency Key"));
        VendorProposal.Status := VendorProposal.Status::Draft;
        VendorProposal.Insert(true);

        exit(ProposalNo);
    end;
}
