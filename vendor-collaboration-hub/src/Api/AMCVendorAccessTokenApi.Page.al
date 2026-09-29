namespace Addmecode.VendorCollaborationHub;

page 50125 "AMC Vendor Access Token API"
{
    APIPublisher = 'addmecode';
    APIGroup = 'collaboration';
    APIVersion = 'v1.0';
    Caption = 'Vendor Access Token API';
    DelayedInsert = true;
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'vendorAccessToken';
    EntitySetName = 'vendorAccessTokens';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "AMC Vendor Access Token" = M;
    SourceTable = "AMC Vendor Access Token";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId)
                {
                    Editable = false;
                }
                field(tokenHash; Rec."Token Hash")
                {
                    Editable = false;
                }
                field(requestNumber; Rec."Request No.")
                {
                    Editable = false;
                }
                field(vendorNumber; Rec."Vendor No.")
                {
                    Editable = false;
                }
                field(status; Rec.Status)
                {
                    Editable = false;
                }
                field(expiresAt; Rec."Expires At")
                {
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Editable = false;
                }
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    var
        ApiTokenScope: Codeunit "AMC API Token Scope";
    begin
        ApiTokenScope.ApplyTokenScope(Rec, false);
        exit(Rec.Find(Which));
    end;

  [ServiceEnabled]
  procedure RegisterAccess(var ActionContext: WebServiceActionContext)
  var
    AccessTokenMgt: Codeunit "AMC Access Token Mgt";
    ApiTokenScope: Codeunit "AMC API Token Scope";
    CollabLog: Codeunit "AMC Collab Log";
    AccessedAt: DateTime;
  begin
    ApiTokenScope.ApplyTokenScope(Rec, true);
    if not Rec.FindFirst() then
      Error(this.TokenNotFoundErr);

    AccessTokenMgt.Assert(Rec."Token Id", Rec."Request No.", Rec."Vendor No.");
    AccessedAt := CurrentDateTime();
    if Rec."First Accessed At" = 0DT then
      Rec."First Accessed At" := AccessedAt;
    Rec."Last Accessed At" := AccessedAt;
    Rec."Access Count" += 1;
    Rec.Modify(true);
    CollabLog.LogEvent("AMC Source Type"::Request, Rec."Request No.", 0, "AMC Collab Entry Type"::LinkOpened, "AMC Actor Type"::Vendor, '', '', false, this.LinkOpenedDescriptionLbl, CreateGuid());

    ActionContext.SetObjectType(ObjectType::Page);
    ActionContext.SetObjectId(Page::"AMC Vendor Access Token API");
    ActionContext.AddEntityKey(Rec.FieldNo(SystemId), Rec.SystemId);
    ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
  end;

  var
    LinkOpenedDescriptionLbl: Label 'Vendor access link opened.';
    TokenNotFoundErr: Label 'VCH-API-0003: The vendor access token was not found.';
}
