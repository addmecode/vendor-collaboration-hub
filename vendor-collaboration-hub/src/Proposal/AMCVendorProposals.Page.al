namespace Addmecode.VendorCollaborationHub;

page 50105 "AMC Vendor Proposals"
{
    ApplicationArea = All;
    Caption = 'Vendor Proposals';
    CardPageId = "AMC Vendor Proposal";
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "AMC Vendor Proposal";
    SourceTableView = sorting(Status, "Submitted Date Time") order(ascending);
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("No."; Rec."No.")
                {
                }
                field("Request No."; Rec."Request No.")
                {
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                }
                field(Status; Rec.Status)
                {
                    Editable = false;
                }
                field("Submitted Date Time"; Rec."Submitted Date Time")
                {
                }
                field("Submitted By"; Rec."Submitted By")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AMCCreateDraftProposal)
            {
                ApplicationArea = All;
                Caption = 'Create draft proposal';
                Image = NewDocument;
                ToolTip = 'Creates a draft proposal for a vendor request.';

                trigger OnAction()
                begin
                    this.CreateDraftProposal();
                end;
            }
        }
    }

    local procedure CreateDraftProposal()
    var
        VendorProposal: Record "AMC Vendor Proposal";
        VendorRequest: Record "AMC Vendor Request";
        ProposalMgt: Codeunit "AMC Proposal Mgt";
        ProposalNo: Code[20];
    begin
        if Page.RunModal(Page::"AMC Vendor Requests", VendorRequest) <> Action::LookupOK then
            exit;

        ProposalNo := ProposalMgt.CreateDraftFromRequest(VendorRequest);
        VendorProposal.Get(ProposalNo);
        Page.Run(Page::"AMC Vendor Proposal", VendorProposal);
    end;
}
