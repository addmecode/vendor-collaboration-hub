namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.Purchases.Vendor;
using System.Threading;
using System.TestLibraries.Utilities;

codeunit 50143 "AMC Access Token Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenVendorRequest_WhenIssue_ThenActiveBoundHashOnlyTokenIsStored()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        VendorAccessToken: Record "AMC Vendor Access Token";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        RawToken: Text;
    begin
        // Given
        RequestNo := this.CreateVendorRequest(VendorNo);
        CollaborationSetup.GetSetup();

        // When
        RawToken := this.IssueToken(RequestNo, VendorAccessToken);

        // Then
        this.Assert.AreEqual(43, StrLen(RawToken), 'The raw token must represent 256 bits as 43 base64url characters.');
        this.Assert.AreNotEqual(RawToken, VendorAccessToken."Token Hash", 'The raw token must not be persisted in the token hash field.');
        this.Assert.AreEqual(VendorNo, VendorAccessToken."Vendor No.", 'The token must be bound to the request vendor.');
        this.Assert.AreEqual(RequestNo, VendorAccessToken."Request No.", 'The token must be bound to its request.');
        this.Assert.AreEqual(VendorAccessToken.Status::Active, VendorAccessToken.Status, 'A newly issued token must be active.');
        this.Assert.AreEqual(UpperCase(VendorAccessToken."Token Hash"), VendorAccessToken."Token Hash", 'The stored token hash must be uppercase.');
        this.Assert.AreEqual(VendorAccessToken."Issued At" + (CollaborationSetup."Link Validity Days" * 24 * 60 * 60 * 1000), VendorAccessToken."Expires At", 'The token expiry must use the setup link validity days.');
        this.Assert.AreEqual('BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD', AccessTokenMgt.HashToken('abc'), 'The token hash helper must return the SHA-256 fixed vector in uppercase hexadecimal.');
    end;

    [Test]
    procedure GivenActiveToken_WhenAssertAndRegisterAccess_ThenOnlyAccessMetadataChangesAndLinkOpenedIsAudited()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        VendorAccessToken: Record "AMC Vendor Access Token";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        ExpiresAt: DateTime;
        IssuedAt: DateTime;
        RequestNo: Code[20];
        TokenHash: Text[64];
        VendorNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateVendorRequest(VendorNo);
        this.IssueToken(RequestNo, VendorAccessToken);
        TokenHash := VendorAccessToken."Token Hash";
        IssuedAt := VendorAccessToken."Issued At";
        ExpiresAt := VendorAccessToken."Expires At";

        // When
        AccessTokenMgt.Assert(VendorAccessToken."Token Id", RequestNo, VendorNo);
        AccessTokenMgt.RegisterAccess(VendorAccessToken."Token Id");

        // Then
        VendorAccessToken.Get(VendorAccessToken."Token Id");
        this.Assert.AreEqual(1, VendorAccessToken."Access Count", 'Registering access must increment the access count.');
        this.Assert.AreNotEqual(0DT, VendorAccessToken."First Accessed At", 'Registering first access must stamp the first access time.');
        this.Assert.AreNotEqual(0DT, VendorAccessToken."Last Accessed At", 'Registering access must stamp the last access time.');
        this.Assert.AreEqual(VendorAccessToken.Status::Active, VendorAccessToken.Status, 'Registering access must not change the token status.');
        this.Assert.AreEqual(TokenHash, VendorAccessToken."Token Hash", 'Registering access must not change the token hash.');
        this.Assert.AreEqual(IssuedAt, VendorAccessToken."Issued At", 'Registering access must not change the issue time.');
        this.Assert.AreEqual(ExpiresAt, VendorAccessToken."Expires At", 'Registering access must not change the expiry time.');
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", RequestNo);
        CollaborationEntry.SetRange("Entry Type", "AMC Collab Entry Type"::LinkOpened);
        this.Assert.IsFalse(CollaborationEntry.IsEmpty(), 'Registering access must add a LinkOpened timeline entry.');
    end;

    [Test]
    procedure GivenTokenForAnotherRequest_WhenAssert_ThenBindingIsRejectedWithoutMutation()
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        ForeignRequestNo: Code[20];
        ForeignVendorNo: Code[20];
        RequestNo: Code[20];
        VendorNo: Code[20];
        VCHAut0004Err: Label 'VCH-AUT-0004: This access link does not belong to the specified request and vendor.';
    begin
        // Given
        RequestNo := this.CreateVendorRequest(VendorNo);
        ForeignRequestNo := this.CreateVendorRequest(ForeignVendorNo);
        this.IssueToken(RequestNo, VendorAccessToken);

        // When
        Commit();
        asserterror AccessTokenMgt.Assert(VendorAccessToken."Token Id", ForeignRequestNo, ForeignVendorNo);

        // Then
        this.Assert.ExpectedError(VCHAut0004Err);
        VendorAccessToken.Get(VendorAccessToken."Token Id");
        this.Assert.AreEqual(0, VendorAccessToken."Access Count", 'A rejected assertion must not register access.');
        this.Assert.AreEqual(0DT, VendorAccessToken."Last Accessed At", 'A rejected assertion must not stamp access metadata.');
    end;

    [Test]
    procedure GivenExpiredOrInactiveToken_WhenAssert_ThenLinkIsRejectedWithoutAccessMutation()
    var
        VendorAccessToken: Record "AMC Vendor Access Token";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateVendorRequest(VendorNo);
        this.IssueToken(RequestNo, VendorAccessToken);

        // When
        VendorAccessToken."Expires At" := CurrentDateTime();
        VendorAccessToken.Modify(true);
        this.AssertInvalidToken(AccessTokenMgt, VendorAccessToken, RequestNo, VendorNo);

        VendorAccessToken."Expires At" := CurrentDateTime() + 60000;
        VendorAccessToken.Status := VendorAccessToken.Status::Expired;
        VendorAccessToken.Modify(true);
        this.AssertInvalidToken(AccessTokenMgt, VendorAccessToken, RequestNo, VendorNo);

        VendorAccessToken.Status := VendorAccessToken.Status::Revoked;
        VendorAccessToken.Modify(true);
        this.AssertInvalidToken(AccessTokenMgt, VendorAccessToken, RequestNo, VendorNo);

        VendorAccessToken.Status := VendorAccessToken.Status::Superseded;
        VendorAccessToken.Modify(true);
        this.AssertInvalidToken(AccessTokenMgt, VendorAccessToken, RequestNo, VendorNo);

        // Then
        VendorAccessToken.Get(VendorAccessToken."Token Id");
        this.Assert.AreEqual(0, VendorAccessToken."Access Count", 'Rejected tokens must not have access registered.');
        this.Assert.AreEqual(0DT, VendorAccessToken."Last Accessed At", 'Rejected tokens must not have access metadata stamped.');
    end;

    [Test]
    procedure GivenActiveToken_WhenRevoked_ThenLifecycleIsAuditedAndAssertionIsRejected()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        VendorAccessToken: Record "AMC Vendor Access Token";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        RequestNo: Code[20];
        VendorNo: Code[20];
        VendorAccessLinks: TestPage "AMC Vendor Access Links";
    begin
        // Given
        RequestNo := this.CreateVendorRequest(VendorNo);
        this.IssueToken(RequestNo, VendorAccessToken);

        // When
        VendorAccessLinks.OpenEdit();
        VendorAccessLinks.GotoRecord(VendorAccessToken);
        VendorAccessLinks.AMCRevokeLink.Invoke();
        VendorAccessLinks.Close();

        // Then
        VendorAccessToken.Get(VendorAccessToken."Token Id");
        this.Assert.AreEqual(VendorAccessToken.Status::Revoked, VendorAccessToken.Status, 'Revoking must set the token status to Revoked.');
        this.Assert.AreNotEqual(0DT, VendorAccessToken."Revoked At", 'Revoking must stamp the revocation time.');
        this.Assert.AreEqual('Revoked by buyer from vendor access links.', VendorAccessToken."Revocation Reason", 'Revoking must retain the revocation reason.');
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", RequestNo);
        CollaborationEntry.SetRange("Entry Type", "AMC Collab Entry Type"::LinkRevoked);
        this.Assert.IsFalse(CollaborationEntry.IsEmpty(), 'Revoking must add a timeline entry.');
        this.AssertInvalidToken(AccessTokenMgt, VendorAccessToken, RequestNo, VendorNo);
    end;

    [Test]
    procedure GivenOldAndOtherActiveTokens_WhenSupersede_ThenOnlyOldRequestTokensChange()
    var
        OtherVendorAccessToken: Record "AMC Vendor Access Token";
        VendorAccessToken: Record "AMC Vendor Access Token";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        OtherRequestNo: Code[20];
        OtherVendorNo: Code[20];
        RequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateVendorRequest(VendorNo);
        OtherRequestNo := this.CreateVendorRequest(OtherVendorNo);
        this.IssueToken(RequestNo, VendorAccessToken);
        this.IssueToken(OtherRequestNo, OtherVendorAccessToken);

        // When
        AccessTokenMgt.Supersede(RequestNo);

        // Then
        VendorAccessToken.Get(VendorAccessToken."Token Id");
        OtherVendorAccessToken.Get(OtherVendorAccessToken."Token Id");
        this.Assert.AreEqual(VendorAccessToken.Status::Superseded, VendorAccessToken.Status, 'Superseding must affect the old request token.');
        this.Assert.AreEqual(OtherVendorAccessToken.Status::Active, OtherVendorAccessToken.Status, 'Superseding must not affect tokens for other requests.');
    end;

    [Test]
    procedure GivenOverdueActiveAndOtherTokens_WhenExpire_ThenOnlyOverdueActiveTokensChange()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        FutureVendorAccessToken: Record "AMC Vendor Access Token";
        InactiveVendorAccessToken: Record "AMC Vendor Access Token";
        OverdueVendorAccessToken: Record "AMC Vendor Access Token";
        FutureRequestNo: Code[20];
        InactiveRequestNo: Code[20];
        OverdueRequestNo: Code[20];
        VendorNo: Code[20];
    begin
        // Given
        OverdueRequestNo := this.CreateVendorRequest(VendorNo);
        this.IssueToken(OverdueRequestNo, OverdueVendorAccessToken);
        OverdueVendorAccessToken."Expires At" := CurrentDateTime() - 60000;
        OverdueVendorAccessToken.Modify(true);

        FutureRequestNo := this.CreateVendorRequest(VendorNo);
        this.IssueToken(FutureRequestNo, FutureVendorAccessToken);
        FutureVendorAccessToken."Expires At" := CurrentDateTime() + 60000;
        FutureVendorAccessToken.Modify(true);

        InactiveRequestNo := this.CreateVendorRequest(VendorNo);
        this.IssueToken(InactiveRequestNo, InactiveVendorAccessToken);
        InactiveVendorAccessToken."Expires At" := CurrentDateTime() - 60000;
        InactiveVendorAccessToken.Status := InactiveVendorAccessToken.Status::Revoked;
        InactiveVendorAccessToken.Modify(true);

        // When
        Codeunit.Run(Codeunit::"AMC Token Expiry Job");

        // Then
        OverdueVendorAccessToken.Get(OverdueVendorAccessToken."Token Id");
        FutureVendorAccessToken.Get(FutureVendorAccessToken."Token Id");
        InactiveVendorAccessToken.Get(InactiveVendorAccessToken."Token Id");
        this.Assert.AreEqual(OverdueVendorAccessToken.Status::Expired, OverdueVendorAccessToken.Status, 'Expiring must change overdue active tokens.');
        this.Assert.AreEqual(FutureVendorAccessToken.Status::Active, FutureVendorAccessToken.Status, 'Expiring must not change future tokens.');
        this.Assert.AreEqual(InactiveVendorAccessToken.Status::Revoked, InactiveVendorAccessToken.Status, 'Expiring must not change inactive tokens.');
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", OverdueRequestNo);
        CollaborationEntry.SetRange("Entry Type", "AMC Collab Entry Type"::LinkExpired);
        this.Assert.IsFalse(CollaborationEntry.IsEmpty(), 'Expiring must add a token lifecycle timeline entry.');
    end;

    [Test]
    procedure GivenCollaborationSetup_WhenSchedulingTokenExpiryJobTwice_ThenOneRecurringJobIsCreated()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        JobQueueEntry: Record "Job Queue Entry";
        CollaborationSetupPage: TestPage "AMC Collaboration Setup";
    begin
        // Given
        CollaborationSetup.GetSetup();
        CollaborationSetupPage.OpenEdit();
        CollaborationSetupPage.GotoRecord(CollaborationSetup);

        // When
        CollaborationSetupPage.AMCScheduleTokenExpiryJob.Invoke();
        CollaborationSetupPage.AMCScheduleTokenExpiryJob.Invoke();

        // Then
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        this.Assert.AreEqual(1, JobQueueEntry.Count(), 'Scheduling the token expiry job repeatedly must retain one job queue entry.');
        JobQueueEntry.FindFirst();
        this.Assert.IsTrue(JobQueueEntry."Recurring Job", 'The token expiry job must recur.');
        CollaborationSetupPage.Close();
    end;

    local procedure AssertInvalidToken(AccessTokenMgt: Codeunit "AMC Access Token Mgt"; VendorAccessToken: Record "AMC Vendor Access Token"; RequestNo: Code[20]; VendorNo: Code[20])
    var
        VCHAut0003Err: Label 'VCH-AUT-0003: This access link is no longer valid.';
    begin
        Commit();
        asserterror AccessTokenMgt.Assert(VendorAccessToken."Token Id", RequestNo, VendorNo);
        this.Assert.ExpectedError(VCHAut0003Err);
    end;

    local procedure CreateVendorRequest(var VendorNo: Code[20]): Code[20]
    var
        Vendor: Record Vendor;
        VendorRequest: Record "AMC Vendor Request";
        RequestNo: Code[20];
    begin
        RequestNo := this.CreateUniqueCode();
        VendorNo := this.CreateUniqueCode();
        Vendor.Init();
        Vendor."No." := VendorNo;
        Vendor.Name := VendorNo;
        Vendor.Insert(false);
        VendorRequest.Init();
        VendorRequest."No." := RequestNo;
        VendorRequest."Vendor No." := VendorNo;
        VendorRequest.Insert(false);
        exit(RequestNo);
    end;

    local procedure IssueToken(RequestNo: Code[20]; var VendorAccessToken: Record "AMC Vendor Access Token"): Text
    var
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        RawToken: Text;
    begin
        RawToken := AccessTokenMgt.Issue(RequestNo);
        VendorAccessToken.SetRange("Token Hash", AccessTokenMgt.HashToken(RawToken));
        VendorAccessToken.FindFirst();
        exit(RawToken);
    end;

    local procedure CreateUniqueCode(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;
}
