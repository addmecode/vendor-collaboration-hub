namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.TestLibraries.Utilities;

codeunit 50132 "AMC Collab Log Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenTimelinePage_WhenOpened_ThenItIsNotEditable()
    var
        CollabTimeline: TestPage "AMC Collab Timeline";
    begin
        // Given

        // When
        CollabTimeline.OpenView();

        // Then
        this.Assert.IsFalse(CollabTimeline.Editable(), 'The collaboration timeline must not be editable.');
        CollabTimeline.Close();
    end;

    [Test]
    procedure GivenLoggedEntry_WhenModified_ThenModificationIsRejected()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        EntryNo: BigInteger;
    begin
        // Given
        EntryNo := this.LogEntry();
        CollaborationEntry.Get(EntryNo);
        CollaborationEntry.Description := 'Changed description.';

        // When
        asserterror CollaborationEntry.Modify(true);

        // Then
        this.Assert.ExpectedError('Collaboration entries cannot be modified.');
    end;

    [Test]
    procedure GivenLoggedEntry_WhenDeleted_ThenDeletionIsRejected()
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        EntryNo: BigInteger;
    begin
        // Given
        EntryNo := this.LogEntry();
        CollaborationEntry.Get(EntryNo);

        // When
        asserterror CollaborationEntry.Delete(true);

        // Then
        this.Assert.ExpectedError('Collaboration entries cannot be deleted.');
    end;

    [Test]
    procedure GivenTelemetryDimensions_WhenMessageIsLogged_ThenEventIdDimensionIsAdded()
    var
        Telemetry: Codeunit "AMC Telemetry";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        // Given
        CustomDimensions.Add('vchRequestNo', this.CreateRequestNo());

        // When
        Telemetry.LogMessage('VCH0101', 'Vendor request created.', Verbosity::Normal, CustomDimensions);

        // Then
        this.Assert.IsTrue(CustomDimensions.ContainsKey('vchEventId'), 'Telemetry must include the logical event-id dimension.');
        this.Assert.AreEqual('VCH0101', CustomDimensions.Get('vchEventId'), 'The logical event-id dimension must match the emitted event id.');
    end;

    local procedure LogEntry(): BigInteger
    var
        CollaborationEntry: Record "AMC Collaboration Entry";
        CollabLog: Codeunit "AMC Collab Log";
        RequestNo: Code[20];
    begin
        RequestNo := this.CreateRequestNo();
        CollabLog.LogEvent("AMC Source Type"::Request, RequestNo, 0, "AMC Collab Entry Type"::RequestCreated, "AMC Actor Type"::System, '', '', false, 'Vendor request created.', CreateGuid());
        CollaborationEntry.SetRange("Source Type", "AMC Source Type"::Request);
        CollaborationEntry.SetRange("Source No.", RequestNo);
        CollaborationEntry.FindFirst();
        exit(CollaborationEntry."Entry No.");
    end;

    local procedure CreateRequestNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;
}
