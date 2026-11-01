namespace Addmecode.VendorCollaborationHub;

page 50106 "AMC Vendor Proposal"
{
    ApplicationArea = All;
    Caption = 'Vendor Proposal';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Document;
    SourceTable = "AMC Vendor Proposal";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("No."; Rec."No.")
                {
                    Editable = false;
                }
                field("Request No."; Rec."Request No.")
                {
                    Editable = false;
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    Editable = false;
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    Editable = false;
                }
                field("Idempotency Key"; Rec."Idempotency Key")
                {
                    Editable = false;
                }
                field("Submitted By"; Rec."Submitted By")
                {
                }
            }
            group(Submission)
            {
                Caption = 'Submission';

                field("Submitted Date Time"; Rec."Submitted Date Time")
                {
                    Editable = false;
                }
                field("Correlation Id"; Rec."Correlation Id")
                {
                    Editable = false;
                }
            }
            part(ProposalLines; "AMC Vendor Proposal Subform")
            {
                Caption = 'Lines';
                SubPageLink = "Proposal No." = field("No.");
                UpdatePropagation = Both;
            }
            part(CollabTimeline; "AMC Collab Timeline")
            {
                Caption = 'Timeline';
                SubPageLink = "Source Type" = const(Proposal), "Source No." = field("No.");
            }
            group(Decision)
            {
                Caption = 'Decision';

                field("Decision Date Time"; Rec."Decision Date Time")
                {
                    Editable = false;
                }
                field("Decision User ID"; Rec."Decision User ID")
                {
                    Editable = false;
                }
                field("Decision Reason"; Rec."Decision Reason")
                {
                    Editable = false;
                }
            }
            group(Apply)
            {
                Caption = 'Apply';

                field("Applied Date Time"; Rec."Applied Date Time")
                {
                    Editable = false;
                }
                field("Apply Attempt Count"; Rec."Apply Attempt Count")
                {
                    Editable = false;
                }
                field("Last Error Code"; Rec."Last Error Code")
                {
                    Editable = false;
                }
                field("Last Error Message"; Rec."Last Error Message")
                {
                    Editable = false;
                }
                field("Superseded By"; Rec."Superseded By")
                {
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ValidateProposal)
            {
                ApplicationArea = All;
                Caption = 'Validate';
                Image = Check;
                ToolTip = 'Validates the proposal without changing it.';

                trigger OnAction()
                var
                    ProposalValidator: Codeunit "AMC Proposal Validator";
                    ValidationResult: Codeunit "AMC Validation Result";
                    ProposalIsValidMsg: Label 'The vendor proposal is valid.';
                begin
                    ProposalValidator.Validate(Rec, ValidationResult);
                    if ValidationResult.HasErrors() then
                        Error(ErrorInfo.Create(ValidationResult.AsDisplayText(), false));

                    Message(ProposalIsValidMsg);
                end;
            }
        }
    }
}
