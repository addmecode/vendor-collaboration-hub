namespace Addmecode.VendorCollaborationHub;

using System.Threading;

codeunit 50124 "AMC Token Expiry Job"
{
    Permissions = tabledata "AMC Vendor Access Token" = RM;

    trigger OnRun()
    begin
        this.ExpireTokens();
    end;

    procedure ExpireTokens()
    var
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
    begin
        //TODO: each token should be expired in separate transaction so when one modification fails the other continue
        AccessTokenMgt.Expire();
    end;

    procedure ScheduleTokenExpiryJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.LockTable();
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        if JobQueueEntry.FindFirst() then
            exit;

        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"AMC Token Expiry Job";
        JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."No. of Minutes between Runs" := 1440;
        JobQueueEntry."User ID" := UserId();
        JobQueueEntry.Insert(true);
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
    end;
}
