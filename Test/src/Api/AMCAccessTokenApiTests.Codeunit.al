namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.TestLibraries.Utilities;

codeunit 50146 "AMC Access Token API Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit "Library Assert";

  [Test]
  procedure GivenExactTokenHash_WhenReadingApi_ThenOnlyMatchingReadOnlyProjectionIsReturned()
  var
    ApiTokenScope: Codeunit "AMC API Token Scope";
    OtherVendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessTokenView: Record "AMC Vendor Access Token";
  begin
    // Given
    this.CreateAccessToken(VendorAccessToken);
    this.CreateAccessToken(OtherVendorAccessToken);
    VendorAccessTokenView.SetRange("Token Hash", VendorAccessToken."Token Hash");

    // When
    ApiTokenScope.ApplyTokenScope(VendorAccessTokenView, false);
    this.Assert.AreEqual(1, VendorAccessTokenView.Count(), 'An exact token hash must not return a second token.');
    VendorAccessTokenView.FindFirst();

    // Then
    this.Assert.AreEqual(VendorAccessToken."Token Hash", VendorAccessTokenView."Token Hash", 'The projection must retain the matching token hash.');
    this.Assert.AreEqual(VendorAccessToken."Request No.", VendorAccessTokenView."Request No.", 'The projection must retain the matching request number.');
    this.Assert.AreEqual(VendorAccessToken."Vendor No.", VendorAccessTokenView."Vendor No.", 'The projection must retain the matching vendor number.');
  end;

  [Test]
  procedure GivenUnscopedOrMalformedTokenHash_WhenReadingApi_ThenReadIsRejected()
  var
    OtherVendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessToken: Record "AMC Vendor Access Token";
    TokenScopeRequiredErr: Label 'VCH-API-0005: Token Hash or an exact id is required.';
  begin
    // Given
    this.CreateAccessToken(VendorAccessToken);
    this.CreateAccessToken(OtherVendorAccessToken);

    // When
    this.AssertUnscopedTokenScopeIsRejected(TokenScopeRequiredErr);
    this.AssertTokenHashScopeIsRejected(LowerCase(VendorAccessToken."Token Hash"));
    this.AssertTokenHashScopeIsRejected(CopyStr(VendorAccessToken."Token Hash", 1, 63));
    this.AssertTokenHashScopeIsRejected(VendorAccessToken."Token Hash" + '*');
    this.AssertTokenHashScopeIsRejected(VendorAccessToken."Token Hash" + '..' + OtherVendorAccessToken."Token Hash");
    this.AssertTokenHashScopeIsRejected('<>' + VendorAccessToken."Token Hash");
    this.AssertTokenHashScopeIsRejected(VendorAccessToken."Token Hash" + '|' + OtherVendorAccessToken."Token Hash");

  end;

  [Test]
  procedure GivenExactSystemId_WhenReadingApiWithoutTokenHash_ThenTokenIsReturnedAndConflictsAreRejected()
  var
    ApiTokenScope: Codeunit "AMC API Token Scope";
    OtherVendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessTokenView: Record "AMC Vendor Access Token";
    TokenScopeMismatchErr: Label 'VCH-API-0004: id and Token Hash do not identify the same vendor access token.';
  begin
    // Given
    this.CreateAccessToken(VendorAccessToken);
    this.CreateAccessToken(OtherVendorAccessToken);
    VendorAccessTokenView.SetRange(SystemId, VendorAccessToken.SystemId);

    // When
    ApiTokenScope.ApplyTokenScope(VendorAccessTokenView, false);
    VendorAccessTokenView.FindFirst();

    // Then
    this.Assert.AreEqual(VendorAccessToken."Token Hash", VendorAccessTokenView."Token Hash", 'An exact SystemId must resolve the matching token.');

    VendorAccessTokenView.Reset();
    VendorAccessTokenView.SetRange(SystemId, VendorAccessToken.SystemId);
    VendorAccessTokenView.SetRange("Token Hash", OtherVendorAccessToken."Token Hash");
    asserterror ApiTokenScope.ApplyTokenScope(VendorAccessTokenView, false);
    this.Assert.ExpectedError(TokenScopeMismatchErr);
    ClearLastError();
  end;

  [Test]
  procedure GivenExactTokenHashAndBroadAdditionalFilters_WhenReadingApi_ThenAnotherTokenCannotLeak()
  var
    ApiTokenScope: Codeunit "AMC API Token Scope";
    OtherVendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessToken: Record "AMC Vendor Access Token";
    VendorAccessTokenView: Record "AMC Vendor Access Token";
  begin
    // Given
    this.CreateAccessToken(VendorAccessToken);
    this.CreateAccessToken(OtherVendorAccessToken);
    VendorAccessTokenView.SetRange("Token Hash", VendorAccessToken."Token Hash");
    VendorAccessTokenView.SetFilter("Vendor No.", '*');
    VendorAccessTokenView.SetFilter("Request No.", '*');

    // When
    ApiTokenScope.ApplyTokenScope(VendorAccessTokenView, false);
    this.Assert.AreEqual(1, VendorAccessTokenView.Count(), 'Additional broad filters must not bypass the exact token hash scope.');
    VendorAccessTokenView.FindFirst();

    // Then
    this.Assert.AreEqual(VendorAccessToken."Token Hash", VendorAccessTokenView."Token Hash", 'The protected token hash scope must be preserved.');
  end;

  local procedure AssertUnscopedTokenScopeIsRejected(ExpectedError: Text)
  var
    ApiTokenScope: Codeunit "AMC API Token Scope";
    VendorAccessTokenView: Record "AMC Vendor Access Token";
  begin
    asserterror ApiTokenScope.ApplyTokenScope(VendorAccessTokenView, false);
    this.Assert.ExpectedError(ExpectedError);
    ClearLastError();
  end;

  local procedure AssertTokenHashScopeIsRejected(TokenHashFilter: Text)
  var
    ApiTokenScope: Codeunit "AMC API Token Scope";
    VendorAccessTokenView: Record "AMC Vendor Access Token";
    InvalidTokenHashScopeErr: Label 'VCH-API-0001: Token Hash must be exactly 64 uppercase hexadecimal characters.';
  begin
    VendorAccessTokenView.SetFilter("Token Hash", TokenHashFilter);
    asserterror ApiTokenScope.ApplyTokenScope(VendorAccessTokenView, false);
    this.Assert.ExpectedError(InvalidTokenHashScopeErr);
    ClearLastError();
  end;

  local procedure CreateAccessToken(var VendorAccessToken: Record "AMC Vendor Access Token")
  var
    AccessTokenMgt: Codeunit "AMC Access Token Mgt";
  begin
    VendorAccessToken.Init();
    VendorAccessToken."Token Id" := CreateGuid();
    VendorAccessToken."Request No." := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(VendorAccessToken."Request No."));
    VendorAccessToken."Vendor No." := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, MaxStrLen(VendorAccessToken."Vendor No."));
    VendorAccessToken."Token Hash" := AccessTokenMgt.HashToken(Format(CreateGuid()));
    VendorAccessToken.Status := VendorAccessToken.Status::Active;
    VendorAccessToken."Expires At" := CurrentDateTime() + 60000;
    VendorAccessToken.Insert(false);
  end;
}
