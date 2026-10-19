namespace Addmecode.VendorCollaborationHub;

page 50124 "AMC Collaboration Comment API"
{
  PageType = API;
  APIPublisher = 'addmecode';
  APIGroup = 'collaboration';
  APIVersion = 'v1.0';
  Caption = 'Collaboration Comment API';
  EntityName = 'collaborationComment';
  EntitySetName = 'collaborationComments';
  SourceTable = "AMC Collaboration Entry";
  Permissions = tabledata "AMC Collaboration Entry" = r;
  SourceTableView = where("Entry Type" = const(Comment));
  ODataKeyFields = SystemId;
  DelayedInsert = true;
  Extensible = false;
  InsertAllowed = true;
  ModifyAllowed = false;
  DeleteAllowed = false;

  layout
  {
    area(Content)
    {
      repeater(General)
      {
        field(id; Rec.SystemId) { Editable = false; }
        field(sourceType; Rec."Source Type") { }
        field(sourceNumber; Rec."Source No.") { }
        field(accessTokenId; this.AccessTokenId) { }
        field(authorName; Rec."Actor Name") { }
        field(comment; Rec.Description) { }
        field(correlationId; Rec."Correlation Id") { }
        field(createdDateTime; Rec."Date Time") { Editable = false; }
        field(lastModifiedDateTime; Rec.SystemModifiedAt) { Editable = false; }
      }
    }
  }

  trigger OnInsertRecord(BelowxRec: Boolean): Boolean
  begin
    this.WriteComment();
    exit(false);
  end;

  trigger OnModifyRecord(): Boolean
  begin
    this.RejectMutation();
  end;

  trigger OnDeleteRecord(): Boolean
  begin
    this.RejectMutation();
  end;

  local procedure WriteComment()
  var
    CollabLog: Codeunit "AMC Collab Log";
  begin
    CollabLog.WriteVendorComment(Rec, this.AccessTokenId);
  end;

  local procedure RejectMutation()
  var
    WriteOnceErr: Label 'VCH-STA-0001: Collaboration comments cannot be updated or deleted through the API.';
  begin
    Error(WriteOnceErr);
  end;

  var
    AccessTokenId: Guid;
}
