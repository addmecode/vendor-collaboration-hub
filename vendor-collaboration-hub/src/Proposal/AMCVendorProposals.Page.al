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
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor proposal number.';
                }
                field("Request No."; Rec."Request No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor request answered by this proposal.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor that made this proposal.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase order answered by this proposal.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the current status of the vendor proposal.';
                }
                field("Submitted Date Time"; Rec."Submitted Date Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor submitted this proposal.';
                }
                field("Submitted By"; Rec."Submitted By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor contact that submitted this proposal.';
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
                Caption = 'Create Draft Proposal';
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
