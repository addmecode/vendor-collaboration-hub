namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;

/// <summary>
/// Replaces notification email handoff with a configured result while manually bound by a test.
/// </summary>
codeunit 50145 "AMC Email Send Test Handler"
{
    EventSubscriberInstance = Manual;

    var
        EmailHandOffSucceeds: Boolean;

    /// <summary>
    /// Sets the result returned by the replacement email handoff while this manual subscriber is bound.
    /// </summary>
    /// <param name="NewEmailHandOffSucceeds">True to simulate successful handoff; false to simulate failure.</param>
    procedure SetEmailHandOffResult(NewEmailHandOffSucceeds: Boolean)
    begin
        this.EmailHandOffSucceeds := NewEmailHandOffSucceeds;
    end;

    /// <summary>
    /// Resets the simulated handoff result to failure without changing subscriber binding.
    /// </summary>
    procedure Reset()
    begin
        this.EmailHandOffSucceeds := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"AMC Vendor Notification", OnSendOnBeforeEmailSend, '', false, false)]
    local procedure "AMC Vendor Notification_OnSendOnBeforeEmailSend"(var IsHandled: Boolean; var EmailWasSent: Boolean)
    begin
        IsHandled := true;
        EmailWasSent := this.EmailHandOffSucceeds;
    end;
}
