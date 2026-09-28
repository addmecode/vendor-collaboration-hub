namespace Addmecode.VendorCollaborationHub;

page 50111 "AMC Vendor Access Links Part"
{
    ApplicationArea = All;
    Caption = 'Vendor Access Links';
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = ListPart;
    SourceTable = "AMC Vendor Access Token";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Token Id"; Rec."Token Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the non-secret identifier of the vendor access link.';
                }
                field("Request No."; Rec."Request No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor request that this link authorizes.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor that this link authorizes.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the vendor access link.';
                }
                field("Issued At"; Rec."Issued At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor access link was issued.';
                }
                field("Expires At"; Rec."Expires At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor access link expires.';
                }
                field("Sent To E-Mail"; Rec."Sent To E-Mail")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the e-mail address to which the vendor access link was sent.';
                }
                field("Sent At"; Rec."Sent At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor access link was sent.';
                }
                field("First Accessed At"; Rec."First Accessed At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor access link was first opened.';
                }
                field("Last Accessed At"; Rec."Last Accessed At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor access link was last opened.';
                }
                field("Access Count"; Rec."Access Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of times the vendor access link was opened.';
                }
                field("Revoked At"; Rec."Revoked At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the vendor access link was revoked.';
                }
                field("Revoked By"; Rec."Revoked By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who revoked the vendor access link.';
                }
                field("Revocation Reason"; Rec."Revocation Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies why the vendor access link was revoked.';
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
                Caption = 'Revoke Link';
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
