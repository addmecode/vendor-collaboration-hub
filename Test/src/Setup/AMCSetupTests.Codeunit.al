namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.Threading;
using System.TestLibraries.Utilities;

codeunit 50130 "AMC Setup Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenMissingSetup_WhenGetSetup_ThenDefaultValuesAreCreated()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        // The temporary setup table has no records.

        // When
        TempCollaborationSetup.GetSetup();


        // Then
        Assert.IsFalse(TempCollaborationSetup.Enabled, 'Vendor collaboration must be disabled by default.');
        Assert.AreEqual(7, TempCollaborationSetup."Default Response Days", 'The default response period must be seven days.');
        Assert.IsFalse(TempCollaborationSetup."Allow Item Substitution", 'Item substitution must be disabled by default.');
        Assert.IsFalse(TempCollaborationSetup."Allow Quantity Increase", 'Quantity increase must be disabled by default.');
        Assert.AreEqual(3, TempCollaborationSetup."Max Splits per Line", 'The default split limit must be three.');
        Assert.IsTrue(TempCollaborationSetup."Require Reason Code", 'A reason code must be required by default.');
        Assert.AreEqual(14, TempCollaborationSetup."Link Validity Days", 'The default link validity must be fourteen days.');
        Assert.AreEqual(TempCollaborationSetup."Telemetry Verbosity"::Normal, TempCollaborationSetup."Telemetry Verbosity", 'The default telemetry verbosity must be Normal.');
    end;

    [Test]
    procedure GivenMissingRequestNoSeries_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Request Nos." := '';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(TempCollaborationSetup.FieldCaption("Request Nos."));
    end;

    [Test]
    procedure GivenMissingProposalNoSeries_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Proposal Nos." := '';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(TempCollaborationSetup.FieldCaption("Proposal Nos."));
    end;

    [Test]
    procedure GivenMissingPortalBaseUrl_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Portal Base URL" := '';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(TempCollaborationSetup.FieldCaption("Portal Base URL"));
    end;

    [Test]
    procedure GivenMissingPortalSupportEmail_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Portal Support E-Mail" := '';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(TempCollaborationSetup.FieldCaption("Portal Support E-Mail"));
    end;

    [Test]
    procedure GivenInvalidPortalBaseUrl_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
        InvalidUriErr: Label 'The URI is not valid.';
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Portal Base URL" := 'portal.contoso.com';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        Assert.ExpectedError(InvalidUriErr);
    end;

    [Test]
    procedure GivenInvalidPortalSupportEmail_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
        InvalidEmailAddressErr: Label 'The email address "%1" is not valid.', Comment = '%1 = invalid e-mail address';
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Portal Support E-Mail" := 'support.contoso.com';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        Assert.ExpectedError(StrSubstNo(InvalidEmailAddressErr, TempCollaborationSetup."Portal Support E-Mail"));
    end;

    [Test]
    procedure GivenNonPositiveResponseDays_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Default Response Days" := 0;

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanZeroError(TempCollaborationSetup.FieldCaption("Default Response Days"));
    end;

    [Test]
    procedure GivenNonPositiveLinkValidityDays_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Link Validity Days" := 0;

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanZeroError(TempCollaborationSetup.FieldCaption("Link Validity Days"));
    end;

    [Test]
    procedure GivenLinkValidityDaysShorterThanResponseDays_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Link Validity Days" := TempCollaborationSetup."Default Response Days" - 1;

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanOrEqualToError(TempCollaborationSetup.FieldCaption("Link Validity Days"), TempCollaborationSetup.FieldCaption("Default Response Days"));
    end;

    [Test]
    procedure GivenNonPositiveMaxSplitsPerLine_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Max Splits per Line" := 0;

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanZeroError(TempCollaborationSetup.FieldCaption("Max Splits per Line"));
    end;

    [Test]
    procedure GivenCompleteSetup_WhenEnabling_ThenSetupIsEnabled()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);

        // When
        TempCollaborationSetup.Validate(Enabled, true);

        // Then
        Assert.IsTrue(TempCollaborationSetup.Enabled, 'Vendor collaboration must be enabled.');
    end;

    [Test]
    procedure GivenAssistedSetup_WhenFinishing_ThenOneTokenExpiryJobIsScheduled()
    var
        AssistedSetup: TestPage "AMC Assisted Setup";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // Given
        this.PrepareAssistedSetupPrerequisites();
        AssistedSetup.OpenEdit();

        // When
        this.GoToAssistedSetupFinishStep(AssistedSetup);
        AssistedSetup.Finish.Invoke();

        // Then
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        Assert.AreEqual(1, JobQueueEntry.Count(), 'Finishing assisted setup must schedule one token expiry job.');
    end;

    [Test]
    procedure GivenAssistedSetup_WhenClosingWithoutFinishing_ThenNoTokenExpiryJobIsScheduled()
    var
        AssistedSetup: TestPage "AMC Assisted Setup";
        CollaborationSetup: Record "AMC Collaboration Setup";
        InitialCollaborationSetup: Record "AMC Collaboration Setup";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        // Given
        this.PrepareAssistedSetupPrerequisites();
        CollaborationSetup.Get();
        InitialCollaborationSetup := CollaborationSetup;
        AssistedSetup.OpenEdit();

        // When
        AssistedSetup.Close();

        // Then
        CollaborationSetup.Get();
        this.AssertCollaborationSetupIsUnchanged(InitialCollaborationSetup, CollaborationSetup);
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        Assert.AreEqual(0, JobQueueEntry.Count(), 'Closing assisted setup must not schedule a token expiry job.');
    end;

    local procedure GoToAssistedSetupFinishStep(var AssistedSetup: TestPage "AMC Assisted Setup")
    begin
        AssistedSetup.Next.Invoke();
        AssistedSetup.Next.Invoke();
        AssistedSetup.Next.Invoke();
        AssistedSetup.Next.Invoke();
    end;

    local procedure PrepareAssistedSetupPrerequisites()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        JobQueueEntry: Record "Job Queue Entry";
    begin
        ClearLastError();
        CollaborationSetup.GetSetup();
        if CollaborationSetup.Enabled then begin
            CollaborationSetup.Enabled := false;
            CollaborationSetup.Modify(true);
        end;

        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        JobQueueEntry.DeleteAll();
    end;

    local procedure AssertCollaborationSetupIsUnchanged(InitialCollaborationSetup: Record "AMC Collaboration Setup"; CollaborationSetup: Record "AMC Collaboration Setup")
    begin
        Assert.AreEqual(InitialCollaborationSetup."Primary Key", CollaborationSetup."Primary Key", 'Closing assisted setup must not change the setup key.');
        Assert.AreEqual(InitialCollaborationSetup.Enabled, CollaborationSetup.Enabled, 'Closing assisted setup must not change whether vendor collaboration is enabled.');
        Assert.AreEqual(InitialCollaborationSetup."Request Nos.", CollaborationSetup."Request Nos.", 'Closing assisted setup must not change the request number series.');
        Assert.AreEqual(InitialCollaborationSetup."Proposal Nos.", CollaborationSetup."Proposal Nos.", 'Closing assisted setup must not change the proposal number series.');
        Assert.AreEqual(InitialCollaborationSetup."Default Response Days", CollaborationSetup."Default Response Days", 'Closing assisted setup must not change the default response days.');
        Assert.AreEqual(InitialCollaborationSetup."Allow Item Substitution", CollaborationSetup."Allow Item Substitution", 'Closing assisted setup must not change item substitution.');
        Assert.AreEqual(InitialCollaborationSetup."Allow Quantity Increase", CollaborationSetup."Allow Quantity Increase", 'Closing assisted setup must not change quantity increase.');
        Assert.AreEqual(InitialCollaborationSetup."Max Splits per Line", CollaborationSetup."Max Splits per Line", 'Closing assisted setup must not change the maximum splits per line.');
        Assert.AreEqual(InitialCollaborationSetup."Require Reason Code", CollaborationSetup."Require Reason Code", 'Closing assisted setup must not change the reason code requirement.');
        Assert.AreEqual(InitialCollaborationSetup."Portal Base URL", CollaborationSetup."Portal Base URL", 'Closing assisted setup must not change the portal base URL.');
        Assert.AreEqual(InitialCollaborationSetup."Portal Support E-Mail", CollaborationSetup."Portal Support E-Mail", 'Closing assisted setup must not change the portal support email.');
        Assert.AreEqual(InitialCollaborationSetup."Link Validity Days", CollaborationSetup."Link Validity Days", 'Closing assisted setup must not change link validity days.');
        Assert.AreEqual(InitialCollaborationSetup."Attach Order PDF", CollaborationSetup."Attach Order PDF", 'Closing assisted setup must not change the attach order PDF setting.');
        Assert.AreEqual(InitialCollaborationSetup."Telemetry Verbosity", CollaborationSetup."Telemetry Verbosity", 'Closing assisted setup must not change telemetry verbosity.');
    end;

    local procedure PrepareCompleteSetup(var TempCollaborationSetup: Record "AMC Collaboration Setup" temporary)
    begin
        TempCollaborationSetup.GetSetup();
        TempCollaborationSetup."Request Nos." := 'REQUEST';
        TempCollaborationSetup."Proposal Nos." := 'PROPOSAL';
        TempCollaborationSetup."Portal Base URL" := 'https://portal.contoso.com';
        TempCollaborationSetup."Portal Support E-Mail" := 'support@contoso.com';
    end;

    local procedure AssertFieldMustBeGreaterThanZeroError(FieldCaption: Text)
    var
        FieldMustBeGreaterThanZeroErr: Label '%1 must be greater than zero.', Comment = '%1 = field caption';
    begin
        Assert.ExpectedError(StrSubstNo(FieldMustBeGreaterThanZeroErr, FieldCaption));
    end;

    local procedure AssertFieldMustHaveValueError(FieldCaption: Text)
    var
        FieldMustHaveValueErr: Label '%1 must have a value', Comment = '%1 = field caption';
    begin
        Assert.ExpectedError(StrSubstNo(FieldMustHaveValueErr, FieldCaption));
    end;

    local procedure AssertFieldMustBeGreaterThanOrEqualToError(FieldCaption: Text; OtherFieldCaption: Text)
    var
        FieldMustBeGreaterThanOrEqualToErr: Label '%1 must be greater than or equal to %2.', Comment = '%1 = field caption, %2 = field caption';
    begin
        Assert.ExpectedError(StrSubstNo(FieldMustBeGreaterThanOrEqualToErr, FieldCaption, OtherFieldCaption));
    end;
}
