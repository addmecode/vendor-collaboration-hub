namespace Addmecode.VendorCollaborationHub;

using System.Threading;

codeunit 50124 "AMC Token Expiry Job"
{
    Permissions = tabledata "Job Queue Entry" = ri;

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

    procedure ScheduleTokenExpiryJob(): Boolean
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.ReadIsolation(IsolationLevel::UpdLock);
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        if not JobQueueEntry.IsEmpty() then
            exit(false);

        JobQueueEntry.Init();
        // Keep field validation from enqueueing the entry before its explicit insert.
        JobQueueEntry.Validate(Status, JobQueueEntry.Status::"On Hold");
        JobQueueEntry.Validate("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.Validate("Object ID to Run", Codeunit::"AMC Token Expiry Job");
        JobQueueEntry.Validate("Earliest Start Date/Time", CurrentDateTime());
        JobQueueEntry.Validate("Run on Mondays", true);
        JobQueueEntry.Validate("Run on Tuesdays", true);
        JobQueueEntry.Validate("Run on Wednesdays", true);
        JobQueueEntry.Validate("Run on Thursdays", true);
        JobQueueEntry.Validate("Run on Fridays", true);
        JobQueueEntry.Validate("Run on Saturdays", true);
        JobQueueEntry.Validate("Run on Sundays", true);
        JobQueueEntry.Validate("No. of Minutes between Runs", 1440);
        JobQueueEntry.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(JobQueueEntry."User ID")));
        JobQueueEntry.Insert(true);
        JobQueueEntry.SetStatus(JobQueueEntry.Status::Ready);
        exit(true);
    end;
}
