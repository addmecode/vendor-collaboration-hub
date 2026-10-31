namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;

codeunit 50145 "AMC Email Send Test Handler"
{
    EventSubscriberInstance = Manual;

    var
        EmailHandOffSucceeds: Boolean;

    procedure SetEmailHandOffResult(NewEmailHandOffSucceeds: Boolean)
    begin
        this.EmailHandOffSucceeds := NewEmailHandOffSucceeds;
    end;

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
