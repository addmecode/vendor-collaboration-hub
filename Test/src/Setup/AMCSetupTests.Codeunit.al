namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
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
    end;

    [Test]
    procedure GivenInvalidPortalBaseUrl_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Portal Base URL" := 'portal.contoso.com';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);
    end;

    [Test]
    procedure GivenInvalidPortalSupportEmail_WhenEnabling_ThenValidationFails()
    var
        TempCollaborationSetup: Record "AMC Collaboration Setup" temporary;
    begin
        // Given
        this.PrepareCompleteSetup(TempCollaborationSetup);
        TempCollaborationSetup."Portal Support E-Mail" := 'support.contoso.com';

        // When
        asserterror TempCollaborationSetup.Validate(Enabled, true);
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

    local procedure AssertFieldMustBeGreaterThanOrEqualToError(FieldCaption: Text; OtherFieldCaption: Text)
    var
        FieldMustBeGreaterThanOrEqualToErr: Label '%1 must be greater than or equal to %2.', Comment = '%1 = field caption, %2 = field caption';
    begin
        Assert.ExpectedError(StrSubstNo(FieldMustBeGreaterThanOrEqualToErr, FieldCaption, OtherFieldCaption));
    end;
}
