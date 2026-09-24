namespace Addmecode.VendorCollaborationHub;

page 50106 "AMC Vendor Proposal"
{
    ApplicationArea = All;
    Caption = 'Vendor Proposal';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Document;
    SourceTable = "AMC Vendor Proposal";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the vendor proposal number.';
                }
                field("Request No."; Rec."Request No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the vendor request answered by this proposal.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the vendor that made this proposal.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the purchase order answered by this proposal.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the current status of the vendor proposal.';
                }
                field("Idempotency Key"; Rec."Idempotency Key")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the caller key used to prevent duplicate proposal submissions.';
                }
                field("Submitted By"; Rec."Submitted By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor contact that submitted this proposal.';
                }
            }
            group(Submission)
            {
                Caption = 'Submission';

                field("Submitted Date Time"; Rec."Submitted Date Time")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when the vendor submitted this proposal.';
                }
                field("Correlation Id"; Rec."Correlation Id")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the identifier that correlates this proposal with telemetry.';
                }
            }
            part(ProposalLines; "AMC Vendor Proposal Subform")
            {
                ApplicationArea = All;
                Caption = 'Lines';
                SubPageLink = "Proposal No." = field("No.");
                UpdatePropagation = Both;
            }
            group(Decision)
            {
                Caption = 'Decision';

                field("Decision Date Time"; Rec."Decision Date Time")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when a decision was made for this proposal.';
                }
                field("Decision User ID"; Rec."Decision User ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the user who made the decision for this proposal.';
                }
                field("Decision Reason"; Rec."Decision Reason")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the reason recorded for the proposal decision.';
                }
            }
            group(Apply)
            {
                Caption = 'Apply';

                field("Applied Date Time"; Rec."Applied Date Time")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when this proposal was applied to the purchase order.';
                }
                field("Apply Attempt Count"; Rec."Apply Attempt Count")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the number of attempts to apply this proposal.';
                }
                field("Last Error Code"; Rec."Last Error Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the most recent error code from applying this proposal.';
                }
                field("Last Error Message"; Rec."Last Error Message")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the most recent error message from applying this proposal.';
                }
                field("Superseded By"; Rec."Superseded By")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the proposal that superseded this proposal.';
                }
            }
        }
    }
}
