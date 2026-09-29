namespace Addmecode.VendorCollaborationHub;

codeunit 50126 "AMC API Token Scope"
{
  procedure ApplyTokenScope(var VendorAccessToken: Record "AMC Vendor Access Token"; AllowBoundSystemId: Boolean)
  var
    ClientFilterGroup: Integer;
    SystemIdFilter: Text;
    TokenHash: Text[64];
    TokenHashFilter: Text;
    TokenSystemId: Guid;
    HasTokenHash: Boolean;
    HasTokenSystemId: Boolean;
  begin
    ClientFilterGroup := VendorAccessToken.FilterGroup();
    VendorAccessToken.FilterGroup(0);
    SystemIdFilter := VendorAccessToken.GetFilter(SystemId);
    TokenHashFilter := VendorAccessToken.GetFilter("Token Hash");
    VendorAccessToken.FilterGroup(ClientFilterGroup);

    HasTokenSystemId := this.TryGetSystemIdScope(VendorAccessToken, SystemIdFilter, AllowBoundSystemId, TokenSystemId);
    HasTokenHash := this.TryGetTokenHashScope(TokenHashFilter, TokenHash);
    if not HasTokenSystemId and not HasTokenHash then
      Error(this.TokenScopeRequiredErr);

    this.ApplyProtectedTokenScope(VendorAccessToken, ClientFilterGroup, HasTokenSystemId, TokenSystemId, HasTokenHash, TokenHash);
    if HasTokenSystemId and HasTokenHash and VendorAccessToken.IsEmpty() then
      Error(this.TokenScopeMismatchErr);
  end;

  local procedure ApplyProtectedTokenScope(var VendorAccessToken: Record "AMC Vendor Access Token"; ClientFilterGroup: Integer; HasTokenSystemId: Boolean; TokenSystemId: Guid; HasTokenHash: Boolean; TokenHash: Text[64])
  begin
    // Filter group 10 is reserved for this codeunit's protected token constraints.
    VendorAccessToken.FilterGroup(10);
    VendorAccessToken.SetRange(SystemId);
    VendorAccessToken.SetRange("Token Hash");
    if HasTokenSystemId then
      VendorAccessToken.SetRange(SystemId, TokenSystemId);
    if HasTokenHash then
      VendorAccessToken.SetRange("Token Hash", TokenHash);
    VendorAccessToken.FilterGroup(ClientFilterGroup);
  end;

  local procedure TryGetSystemIdScope(VendorAccessToken: Record "AMC Vendor Access Token"; SystemIdFilter: Text; AllowBoundSystemId: Boolean; var TokenSystemId: Guid): Boolean
  begin
    if SystemIdFilter = '' then begin
      if not AllowBoundSystemId or IsNullGuid(VendorAccessToken.SystemId) then
        exit(false);

      TokenSystemId := VendorAccessToken.SystemId;
      exit(true);
    end;

    if not this.IsGuid(SystemIdFilter, TokenSystemId) then
      Error(this.InvalidTokenSystemIdScopeErr);

    exit(true);
  end;

  local procedure TryGetTokenHashScope(TokenHashFilter: Text; var TokenHash: Text[64]): Boolean
  begin
    if TokenHashFilter = '' then
      exit(false);

    if not this.IsTokenHash(TokenHashFilter) then
      Error(this.InvalidTokenHashScopeErr);

    TokenHash := TokenHashFilter;
    exit(true);
  end;

  local procedure IsGuid(Value: Text; var TokenSystemId: Guid): Boolean
  var
    GuidText: Text;
  begin
    GuidText := Value;
    if (StrLen(GuidText) = 38) and (GuidText[1] = '{') and (GuidText[38] = '}') then
      GuidText := CopyStr(GuidText, 2, 36);

    if (StrLen(GuidText) <> 36) or
      (GuidText[9] <> '-') or
      (GuidText[14] <> '-') or
      (GuidText[19] <> '-') or
      (GuidText[24] <> '-') then
      exit(false);

    GuidText := DelChr(GuidText, '=', '-');
    if (StrLen(GuidText) <> 32) or (DelChr(UpperCase(GuidText), '=', '0123456789ABCDEF') <> '') then
      exit(false);

    exit(Evaluate(TokenSystemId, Value));
  end;

  local procedure IsTokenHash(Value: Text): Boolean
  begin
    exit((StrLen(Value) = 64) and (DelChr(Value, '=', '0123456789ABCDEF') = ''));
  end;

  var
    InvalidTokenHashScopeErr: Label 'VCH-API-0001: Token Hash must be exactly 64 uppercase hexadecimal characters.';
    InvalidTokenSystemIdScopeErr: Label 'VCH-API-0002: id must be an exact SystemId.';
    TokenScopeMismatchErr: Label 'VCH-API-0004: id and Token Hash do not identify the same vendor access token.';
    TokenScopeRequiredErr: Label 'VCH-API-0005: Token Hash or an exact id is required.';
}
