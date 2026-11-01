namespace Addmecode.VendorCollaborationHub;

page 50110 "AMC Vendor Access Links"
{
    ApplicationArea = All;
    Caption = 'Vendor Access Links';
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    SourceTable = "AMC Vendor Access Token";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Token Id"; Rec."Token Id")
                {
                }
                field("Request No."; Rec."Request No.")
                {
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                }
                field(Status; Rec.Status)
                {
                }
                field("Issued At"; Rec."Issued At")
                {
                }
                field("Expires At"; Rec."Expires At")
                {
                }
                field("Sent To E-Mail"; Rec."Sent To E-Mail")
                {
                }
                field("Sent At"; Rec."Sent At")
                {
                }
                field("First Accessed At"; Rec."First Accessed At")
                {
                }
                field("Last Accessed At"; Rec."Last Accessed At")
                {
                }
                field("Access Count"; Rec."Access Count")
                {
                }
                field("Revoked At"; Rec."Revoked At")
                {
                }
                field("Revoked By"; Rec."Revoked By")
                {
                }
                field("Revocation Reason"; Rec."Revocation Reason")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AMCRevokeLink)
            {
                ApplicationArea = All;
                Caption = 'Revoke link';
                Enabled = Rec.Status = Rec.Status::Active;
                Image = Cancel;
                ToolTip = 'Revokes the selected vendor access link.';

                trigger OnAction()
                begin
                    this.RevokeLink();
                end;
            }
        }
    }

    local procedure RevokeLink()
    var
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        RevokedByBuyerLbl: Label 'Revoked by buyer from vendor access links.';
    begin
        AccessTokenMgt.Revoke(Rec."Token Id", RevokedByBuyerLbl);
        CurrPage.Update(false);
    end;
}
