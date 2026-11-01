namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.TestLibraries.Utilities;
using System.Threading;

codeunit 50130 "AMC Setup Tests"
{
    Subtype = Test;
    Permissions = tabledata "AMC Collaboration Setup" = rm,
                  tabledata "Job Queue Entry" = rd;

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
        this.Assert.IsFalse(TempCollaborationSetup.Enabled, 'Vendor collaboration must be disabled by default.');
        this.Assert.AreEqual(7, TempCollaborationSetup."Default Response Days", 'The default response period must be seven days.');
        this.Assert.IsFalse(TempCollaborationSetup."Allow Item Substitution", 'Item substitution must be disabled by default.');
        this.Assert.IsFalse(TempCollaborationSetup."Allow Quantity Increase", 'Quantity increase must be disabled by default.');
        this.Assert.AreEqual(3, TempCollaborationSetup."Max Splits per Line", 'The default split limit must be three.');
        this.Assert.IsTrue(TempCollaborationSetup."Require Reason Code", 'A reason code must be required by default.');
        this.Assert.AreEqual(14, TempCollaborationSetup."Link Validity Days", 'The default link validity must be fourteen days.');
        this.Assert.AreEqual(TempCollaborationSetup."Telemetry Verbosity"::Normal, TempCollaborationSetup."Telemetry Verbosity", 'The default telemetry verbosity must be Normal.');
    end;

    [Test]
    procedure GivenMissingRequestNoSeries_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Request Nos.", '');

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(CollaborationSetup.FieldCaption("Request Nos."));
    end;

    [Test]
    procedure GivenMissingProposalNoSeries_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Proposal Nos.", '');

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(CollaborationSetup.FieldCaption("Proposal Nos."));
    end;

    [Test]
    procedure GivenMissingPortalBaseUrl_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Portal Base URL", '');

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(CollaborationSetup.FieldCaption("Portal Base URL"));
    end;

    [Test]
    procedure GivenMissingPortalSupportEmail_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Portal Support E-Mail", '');

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustHaveValueError(CollaborationSetup.FieldCaption("Portal Support E-Mail"));
    end;

    [Test]
    procedure GivenInvalidPortalBaseUrl_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        InvalidUriErr: Label 'The URI is not valid.';
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Portal Base URL", 'portal.contoso.com');

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.Assert.ExpectedError(InvalidUriErr);
    end;

    [Test]
    procedure GivenInvalidPortalSupportEmail_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        InvalidEmailAddressErr: Label 'The email address "%1" is not valid.', Comment = '%1 = invalid e-mail address';
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Portal Support E-Mail", 'support.contoso.com');

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.Assert.ExpectedError(StrSubstNo(InvalidEmailAddressErr, CollaborationSetup."Portal Support E-Mail"));
    end;

    [Test]
    procedure GivenNonPositiveResponseDays_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Default Response Days", 0);

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanZeroError(CollaborationSetup.FieldCaption("Default Response Days"));
    end;

    [Test]
    procedure GivenNonPositiveLinkValidityDays_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Link Validity Days", 0);

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanZeroError(CollaborationSetup.FieldCaption("Link Validity Days"));
    end;

    [Test]
    procedure GivenLinkValidityDaysShorterThanResponseDays_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Link Validity Days", CollaborationSetup."Default Response Days" - 1);

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanOrEqualToError(CollaborationSetup.FieldCaption("Link Validity Days"), CollaborationSetup.FieldCaption("Default Response Days"));
    end;

    [Test]
    procedure GivenNonPositiveMaxSplitsPerLine_WhenEnabling_ThenValidationFails()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);
        CollaborationSetup.Validate("Max Splits per Line", 0);

        // When
        asserterror CollaborationSetup.Validate(Enabled, true);

        // Then
        this.AssertFieldMustBeGreaterThanZeroError(CollaborationSetup.FieldCaption("Max Splits per Line"));
    end;

    [Test]
    procedure GivenCompleteSetup_WhenEnabling_ThenSetupIsEnabled()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
    begin
        // Given
        this.PrepareCompleteSetup(CollaborationSetup);

        // When
        CollaborationSetup.Validate(Enabled, true);

        // Then
        this.Assert.IsTrue(CollaborationSetup.Enabled, 'Vendor collaboration must be enabled.');
    end;

    [Test]
    procedure GivenAssistedSetup_WhenFinishing_ThenOneTokenExpiryJobIsScheduled()
    var
        JobQueueEntry: Record "Job Queue Entry";
        AssistedSetup: TestPage "AMC Assisted Setup";
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
        this.Assert.AreEqual(1, JobQueueEntry.Count(), 'Finishing assisted setup must schedule one token expiry job.');
    end;

    [Test]
    procedure GivenAssistedSetup_WhenClosingWithoutFinishing_ThenNoTokenExpiryJobIsScheduled()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        InitialCollaborationSetup: Record "AMC Collaboration Setup";
        JobQueueEntry: Record "Job Queue Entry";
        AssistedSetup: TestPage "AMC Assisted Setup";
    begin
        // Given
        this.PrepareAssistedSetupPrerequisites();
        this.Assert.IsTrue(CollaborationSetup.Get(), 'The expected collaboration setup record must exist.');
        InitialCollaborationSetup := CollaborationSetup;
        AssistedSetup.OpenEdit();

        // When
        AssistedSetup.Close();

        // Then
        this.Assert.IsTrue(CollaborationSetup.Get(), 'The expected collaboration setup record must exist.');
        this.AssertCollaborationSetupIsUnchanged(InitialCollaborationSetup, CollaborationSetup);
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        this.Assert.AreEqual(0, JobQueueEntry.Count(), 'Closing assisted setup must not schedule a token expiry job.');
    end;

    [Test]
    procedure GivenEnabledSetup_WhenOpeningAssistedSetup_ThenOpeningIsRejectedWithoutMutation()
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        InitialCollaborationSetup: Record "AMC Collaboration Setup";
        JobQueueEntry: Record "Job Queue Entry";
        PreparedCollaborationSetup: Record "AMC Collaboration Setup";
        CollaborationSetupPage: Page "AMC Collaboration Setup";
        AssistedSetup: TestPage "AMC Assisted Setup";
        AssistedSetupNotAvailableErr: Label 'Vendor Collaboration is already enabled. Use the %1 page to change the configuration.', Comment = '%1 = page caption';
    begin
        // Given
        this.PrepareAssistedSetupPrerequisites();
        this.PrepareCompleteSetup(PreparedCollaborationSetup);
        CollaborationSetup := PreparedCollaborationSetup;
        CollaborationSetup.Validate(Enabled, true);
        CollaborationSetup.Modify(true);
        Commit(); // Keep the enabled fixture outside the expected page-opening error's rollback.
        this.Assert.IsTrue(CollaborationSetup.Get(), 'The expected collaboration setup record must exist.');
        InitialCollaborationSetup := CollaborationSetup;

        // When
        asserterror AssistedSetup.OpenEdit();

        // Then
        this.Assert.ExpectedError(StrSubstNo(AssistedSetupNotAvailableErr, CollaborationSetupPage.Caption()));
        this.Assert.IsTrue(CollaborationSetup.Get(), 'The expected collaboration setup record must exist.');
        this.AssertCollaborationSetupIsUnchanged(InitialCollaborationSetup, CollaborationSetup);
        this.Assert.AreEqual(InitialCollaborationSetup.SystemModifiedAt, CollaborationSetup.SystemModifiedAt, 'Rejecting assisted setup must not write the enabled setup record.');
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        this.Assert.AreEqual(0, JobQueueEntry.Count(), 'Rejecting assisted setup must not schedule a token expiry job.');
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
            CollaborationSetup.Validate(Enabled, false);
            CollaborationSetup.Modify(true);
        end;

        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        JobQueueEntry.DeleteAll(false);
    end;

    local procedure AssertCollaborationSetupIsUnchanged(InitialCollaborationSetup: Record "AMC Collaboration Setup"; CollaborationSetup: Record "AMC Collaboration Setup")
    begin
        this.Assert.AreEqual(InitialCollaborationSetup."Primary Key", CollaborationSetup."Primary Key", 'Closing assisted setup must not change the setup key.');
        this.Assert.AreEqual(InitialCollaborationSetup.Enabled, CollaborationSetup.Enabled, 'Closing assisted setup must not change whether vendor collaboration is enabled.');
        this.Assert.AreEqual(InitialCollaborationSetup."Request Nos.", CollaborationSetup."Request Nos.", 'Closing assisted setup must not change the request number series.');
        this.Assert.AreEqual(InitialCollaborationSetup."Proposal Nos.", CollaborationSetup."Proposal Nos.", 'Closing assisted setup must not change the proposal number series.');
        this.Assert.AreEqual(InitialCollaborationSetup."Default Response Days", CollaborationSetup."Default Response Days", 'Closing assisted setup must not change the default response days.');
        this.Assert.AreEqual(InitialCollaborationSetup."Allow Item Substitution", CollaborationSetup."Allow Item Substitution", 'Closing assisted setup must not change item substitution.');
        this.Assert.AreEqual(InitialCollaborationSetup."Allow Quantity Increase", CollaborationSetup."Allow Quantity Increase", 'Closing assisted setup must not change quantity increase.');
        this.Assert.AreEqual(InitialCollaborationSetup."Max Splits per Line", CollaborationSetup."Max Splits per Line", 'Closing assisted setup must not change the maximum splits per line.');
        this.Assert.AreEqual(InitialCollaborationSetup."Require Reason Code", CollaborationSetup."Require Reason Code", 'Closing assisted setup must not change the reason code requirement.');
        this.Assert.AreEqual(InitialCollaborationSetup."Portal Base URL", CollaborationSetup."Portal Base URL", 'Closing assisted setup must not change the portal base URL.');
        this.Assert.AreEqual(InitialCollaborationSetup."Portal Support E-Mail", CollaborationSetup."Portal Support E-Mail", 'Closing assisted setup must not change the portal support email.');
        this.Assert.AreEqual(InitialCollaborationSetup."Link Validity Days", CollaborationSetup."Link Validity Days", 'Closing assisted setup must not change link validity days.');
        this.Assert.AreEqual(InitialCollaborationSetup."Attach Order PDF", CollaborationSetup."Attach Order PDF", 'Closing assisted setup must not change the attach order PDF setting.');
        this.Assert.AreEqual(InitialCollaborationSetup."Telemetry Verbosity", CollaborationSetup."Telemetry Verbosity", 'Closing assisted setup must not change telemetry verbosity.');
    end;

    local procedure PrepareCompleteSetup(var CollaborationSetup: Record "AMC Collaboration Setup")
    var
        TestLibrary: Codeunit "AMC Test Library";
    begin
        // Use an uninserted normal buffer so activation tests exercise the real field trigger without setup writes.
        CollaborationSetup.Init();
        CollaborationSetup.Validate("Default Response Days", 7);
        CollaborationSetup.Validate("Max Splits per Line", 3);
        CollaborationSetup.Validate("Require Reason Code", true);
        CollaborationSetup.Validate("Link Validity Days", 14);
        CollaborationSetup.Validate("Request Nos.", TestLibrary.CreateNumberSeries());
        CollaborationSetup.Validate("Proposal Nos.", TestLibrary.CreateNumberSeries());
        CollaborationSetup.Validate("Portal Base URL", 'https://portal.contoso.com');
        CollaborationSetup.Validate("Portal Support E-Mail", 'support@contoso.com');
    end;

    local procedure AssertFieldMustBeGreaterThanZeroError(FieldCaption: Text)
    var
        FieldMustBeGreaterThanZeroErr: Label '%1 must be greater than zero.', Comment = '%1 = field caption';
    begin
        this.Assert.ExpectedError(StrSubstNo(FieldMustBeGreaterThanZeroErr, FieldCaption));
    end;

    local procedure AssertFieldMustHaveValueError(FieldCaption: Text)
    var
        FieldMustHaveValueErr: Label '%1 must have a value', Comment = '%1 = field caption';
    begin
        this.Assert.ExpectedError(StrSubstNo(FieldMustHaveValueErr, FieldCaption));
    end;

    local procedure AssertFieldMustBeGreaterThanOrEqualToError(FieldCaption: Text; OtherFieldCaption: Text)
    var
        FieldMustBeGreaterThanOrEqualToErr: Label '%1 must be greater than or equal to %2.', Comment = '%1 = field caption, %2 = field caption';
    begin
        this.Assert.ExpectedError(StrSubstNo(FieldMustBeGreaterThanOrEqualToErr, FieldCaption, OtherFieldCaption));
    end;
}
