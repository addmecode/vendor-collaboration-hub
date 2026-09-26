namespace Addmecode.VendorCollaborationHub;

using System.Security.Encryption;
using System.Text;
using System.Utilities;

codeunit 50117 "AMC Access Token Mgt"
{
    procedure Issue(RequestNo: Code[20]): Text
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        VendorAccessToken: Record "AMC Vendor Access Token";
        VendorRequest: Record "AMC Vendor Request";
        CollabLog: Codeunit "AMC Collab Log";
        RawToken: Text;
        IssuedAt: DateTime;
    begin
        VendorRequest.Get(RequestNo);
        CollaborationSetup.GetSetup();

        RawToken := this.CreateRawToken();
        IssuedAt := CurrentDateTime();

        VendorAccessToken.Init();
        VendorAccessToken."Token Id" := CreateGuid();
        VendorAccessToken."Request No." := VendorRequest."No.";
        VendorAccessToken."Vendor No." := VendorRequest."Vendor No.";
        VendorAccessToken."Token Hash" := this.HashToken(RawToken);
        VendorAccessToken.Status := VendorAccessToken.Status::Active;
        VendorAccessToken."Issued At" := IssuedAt;
        VendorAccessToken."Expires At" := IssuedAt + this.GetTokenLifetime(CollaborationSetup."Link Validity Days");
        VendorAccessToken.Insert(true);

        CollabLog.LogEvent("AMC Source Type"::Request, VendorRequest."No.", 0, "AMC Collab Entry Type"::LinkIssued, "AMC Actor Type"::Buyer, '', UserId(), false, this.LinkIssuedDescriptionLbl, CreateGuid());
        exit(RawToken);
    end;

    procedure Assert(TokenId: Guid; RequestNo: Code[20]; VendorNo: Code[20])
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
    begin
        if not VendorAccessToken.Get(TokenId) then
            Error(this.VCHAut0003Err);

        this.AssertActive(VendorAccessToken);
        if (VendorAccessToken."Request No." <> RequestNo) or (VendorAccessToken."Vendor No." <> VendorNo) then
            Error(this.VCHAut0004Err);
    end;

    procedure RegisterAccess(TokenId: Guid)
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
        CollabLog: Codeunit "AMC Collab Log";
        AccessedAt: DateTime;
    begin
        if not VendorAccessToken.Get(TokenId) then
            Error(this.VCHAut0003Err);

        this.AssertActive(VendorAccessToken);
        AccessedAt := CurrentDateTime();
        if VendorAccessToken."First Accessed At" = 0DT then
            VendorAccessToken."First Accessed At" := AccessedAt;
        VendorAccessToken."Last Accessed At" := AccessedAt;
        VendorAccessToken."Access Count" += 1;
        VendorAccessToken.Modify(true);

        CollabLog.LogEvent("AMC Source Type"::Request, VendorAccessToken."Request No.", 0, "AMC Collab Entry Type"::LinkOpened, "AMC Actor Type"::Vendor, '', '', false, this.LinkOpenedDescriptionLbl, CreateGuid());
    end;

    procedure Revoke(TokenId: Guid; RevocationReason: Text[250])
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
    begin
        if not VendorAccessToken.Get(TokenId) then
            exit;

        if VendorAccessToken.Status <> VendorAccessToken.Status::Active then
            exit;

        VendorAccessToken.Status := VendorAccessToken.Status::Revoked;
        VendorAccessToken."Revoked At" := CurrentDateTime();
        VendorAccessToken."Revoked By" := CopyStr(UserId(), 1, MaxStrLen(VendorAccessToken."Revoked By"));
        VendorAccessToken."Revocation Reason" := RevocationReason;
        VendorAccessToken.Modify(true);
        this.LogTokenLifecycle(VendorAccessToken, "AMC Actor Type"::Buyer, this.LinkRevokedDescriptionLbl);
    end;

    procedure Supersede(RequestNo: Code[20])
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
    begin
        VendorAccessToken.SetRange("Request No.", RequestNo);
        VendorAccessToken.SetRange(Status, VendorAccessToken.Status::Active);
        while VendorAccessToken.FindFirst() do begin //todo: findset
            VendorAccessToken.Status := VendorAccessToken.Status::Superseded;
            VendorAccessToken.Modify(true);
            this.LogTokenLifecycle(VendorAccessToken, "AMC Actor Type"::Buyer, this.LinkSupersededDescriptionLbl);
        end;
    end;

    procedure Expire()
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
    begin
        VendorAccessToken.SetRange(Status, VendorAccessToken.Status::Active);
        VendorAccessToken.SetFilter("Expires At", '<%1', CurrentDateTime());
        while VendorAccessToken.FindFirst() do begin //todo: findset
            VendorAccessToken.Status := VendorAccessToken.Status::Expired;
            VendorAccessToken.Modify(true);
            this.LogTokenLifecycle(VendorAccessToken, "AMC Actor Type"::System, this.LinkExpiredDescriptionLbl);
        end;
    end;

    procedure HashToken(RawToken: Text): Text[64]
    var
        CryptographyManagement: Codeunit "Cryptography Management";
        HashAlgorithmType: Option MD5,SHA1,SHA256,SHA384,SHA512;
    begin
        exit(UpperCase(CryptographyManagement.GenerateHash(RawToken, HashAlgorithmType::SHA256)));
    end;

    local procedure AssertActive(VendorAccessToken: Record "AMC Vendor Access Token")
    begin
        if (VendorAccessToken.Status <> VendorAccessToken.Status::Active) or (VendorAccessToken."Expires At" <= CurrentDateTime()) then
            Error(this.VCHAut0003Err);
    end;

    local procedure CreateRawToken(): Text
    var
        CryptographyManagement: Codeunit "Cryptography Management";
        EntropySource: Text;
        HashAlgorithmType: Option MD5,SHA1,SHA256,SHA384,SHA512;
    begin
        EntropySource := Format(CreateGuid()) + Format(CreateGuid()) + Format(CreateGuid());
        exit(this.HashToBase64Url(CryptographyManagement.GenerateHash(EntropySource, HashAlgorithmType::SHA256)));
    end;

    local procedure HashToBase64Url(Hash: Text): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        InStream: InStream;
        OutStream: OutStream;
        ByteValue: Byte;
        Index: Integer;
    begin
        TempBlob.CreateOutStream(OutStream);
        for Index := 1 to 32 do begin
            ByteValue := this.HexDigitValue(Hash[(Index * 2) - 1]) * 16 + this.HexDigitValue(Hash[Index * 2]);
            OutStream.Write(ByteValue);
        end;
        TempBlob.CreateInStream(InStream);
        exit(Base64Convert.ToBase64Url(InStream));
    end;

    local procedure HexDigitValue(HexDigit: Char): Integer
    begin
        exit(StrPos('0123456789ABCDEF', UpperCase(Format(HexDigit))) - 1);
    end;

    local procedure GetTokenLifetime(LinkValidityDays: Integer): Duration
    begin
        exit(LinkValidityDays * 24 * 60 * 60 * 1000);
    end;

    local procedure LogTokenLifecycle(VendorAccessToken: Record "AMC Vendor Access Token"; ActorType: Enum "AMC Actor Type"; Description: Text[250])
    var
        CollabLog: Codeunit "AMC Collab Log";
    begin
        CollabLog.LogEvent("AMC Source Type"::Request, VendorAccessToken."Request No.", 0, "AMC Collab Entry Type"::LinkRevoked, ActorType, '', UserId(), false, Description, CreateGuid());
    end;

    var
        VCHAut0003Err: Label 'VCH-AUT-0003: This access link is no longer valid.';
        VCHAut0004Err: Label 'VCH-AUT-0004: This access link does not belong to the specified request and vendor.';
        LinkIssuedDescriptionLbl: Label 'Vendor access link issued.';
        LinkOpenedDescriptionLbl: Label 'Vendor access link opened.';
        LinkRevokedDescriptionLbl: Label 'Vendor access link revoked.';
        LinkSupersededDescriptionLbl: Label 'Vendor access link superseded.';
        LinkExpiredDescriptionLbl: Label 'Vendor access link expired.';
}
