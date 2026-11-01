namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Globalization;

/// <summary>
/// Creates purchase-order snapshots, sends requests and manages request status and order locking.
/// </summary>
codeunit 50100 "AMC Request Mgt"
{
    Permissions = tabledata "AMC Vendor Request" = rim,
                  tabledata "AMC Vendor Request Line" = i,
                  tabledata "Purchase Header" = rm,
                  tabledata "Purchase Line" = r,
                  tabledata Vendor = r;

    /// <summary>
    /// Validates an open order, creates a draft request and line snapshots, and locks the order to that request.
    /// </summary>
    /// <param name="PurchaseHeader">The order to reread, lock and update with the active request.</param>
    /// <returns>The created request number.</returns>
    procedure CreateFromOrder(var PurchaseHeader: Record "Purchase Header"): Code[20]
    var
        CollaborationSetup: Record "AMC Collaboration Setup";
        PurchaseLine: Record "Purchase Line";
        Vendor: Record Vendor;
        VendorRequest: Record "AMC Vendor Request";
        VendorRequestLine: Record "AMC Vendor Request Line";
        CollabLog: Codeunit "AMC Collab Log";
        NoSeries: Codeunit "No. Series";
        Telemetry: Codeunit "AMC Telemetry";
        RequestNo: Code[20];
        OrderNo: Code[20];
        LineCount: Integer;
        RequestCreatedDescriptionLbl: Label 'Vendor request created.';
    begin
        OrderNo := PurchaseHeader."No.";
        // Keep transaction-wide isolation for the caller and nested purchase-header guard buffers.
        PurchaseHeader.LockTable();
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, OrderNo) then
            Error(this.RequiredRecordNotFoundErr, PurchaseHeader.TableCaption());

        this.VerifyPurchaseOrderCanCreateRequest(PurchaseHeader);

        CollaborationSetup.GetSetup();
        this.VerifyCollaborationEnabled(CollaborationSetup);

        if not Vendor.Get(PurchaseHeader."Buy-from Vendor No.") then
            Error(this.RequiredRecordNotFoundErr, Vendor.TableCaption());
        this.VerifyVendorCollaborationEnabled(Vendor);
        this.VerifyNoActiveRequest(PurchaseHeader."No.");

        RequestNo := NoSeries.GetNextNo(CollaborationSetup."Request Nos.");
        this.CreateVendorRequest(VendorRequest, RequestNo, PurchaseHeader, Vendor, CollaborationSetup);
        LineCount := this.CreateVendorRequestLines(VendorRequestLine, RequestNo, PurchaseHeader, PurchaseLine);

        //todo: move to a separate function?
        PurchaseHeader.Validate("AMC Active Request No.", RequestNo);
        PurchaseHeader.Validate("AMC Collaboration Status", VendorRequest.Status);
        PurchaseHeader.Modify(true);

        CollabLog.LogEvent("AMC Source Type"::Request, RequestNo, 0, "AMC Collab Entry Type"::RequestCreated, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), RequestCreatedDescriptionLbl, CreateGuid());
        Telemetry.LogRequestCreated(RequestNo, PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."No.", LineCount);

        exit(RequestNo);
    end;

    /// <summary>
    /// Opens the vendor request document or raises an error if it no longer exists.
    /// </summary>
    /// <param name="RequestNo">The request number to display.</param>
    procedure OpenRequest(RequestNo: Code[20])
    var
        VendorRequest: Record "AMC Vendor Request";
    begin
        if not VendorRequest.Get(RequestNo) then
            Error(this.RequiredRecordNotFoundErr, VendorRequest.TableCaption());
        Page.Run(Page::"AMC Vendor Request", VendorRequest);
    end;

    /// <summary>
    /// Cancels the order's active nonterminal request, revokes its tokens and clears the order lock with scoped suppression.
    /// </summary>
    /// <param name="PurchaseHeader">The purchase order to reread and unlock.</param>
    procedure Cancel(var PurchaseHeader: Record "Purchase Header")
    var
        VendorRequest: Record "AMC Vendor Request";
        CollabLog: Codeunit "AMC Collab Log";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
        PreviousPurchaseOrderNo: Code[20];
        PreviousRequestNo: Code[20];
        RequestNo: Code[20];
        PurchaseOrderNo: Code[20];
        LastErrorText: Text;
        NoActiveRequestErr: Label 'Purchase order %1 does not have an active vendor request.', Comment = '%1 = purchase order number';
        PurchaseOrderOnlyErr: Label 'Only purchase orders can be unlocked.';
        RequestCancelledDescriptionLbl: Label 'Vendor request cancelled and purchase order unlocked.';
        LinkRevokedOnCancellationDescriptionLbl: Label 'Vendor request was cancelled.';
        RequestCancellationFailedErr: Label 'The vendor request could not be cancelled: %1', Comment = '%1 = original error detail';
    begin
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::Order then
            Error(PurchaseOrderOnlyErr);

        PurchaseOrderNo := PurchaseHeader."No.";
        // Cancellation and its nested order-lock checks must share the transaction's isolation state.
        PurchaseHeader.LockTable();
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, PurchaseOrderNo) then
            Error(this.RequiredRecordNotFoundErr, PurchaseHeader.TableCaption());
        RequestNo := PurchaseHeader."AMC Active Request No.";
        if RequestNo = '' then
            Error(NoActiveRequestErr, PurchaseOrderNo);
        if not VendorRequest.Get(RequestNo) then
            Error(NoActiveRequestErr, PurchaseOrderNo);
        this.VerifyPurchaseOrderCanBeCancelled(PurchaseHeader, VendorRequest);

        this.SetStatus(VendorRequest, VendorRequest.Status::Cancelled);
        AccessTokenMgt.RevokeRequestTokens(RequestNo, LinkRevokedOnCancellationDescriptionLbl);

        OrderLockMgt.SetSuppressionContext(PurchaseOrderNo, RequestNo, PreviousPurchaseOrderNo, PreviousRequestNo);
        if not this.TryClearPurchaseOrderRequest(PurchaseHeader, VendorRequest.Status) then begin
            LastErrorText := GetLastErrorText();
            OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
            Error(RequestCancellationFailedErr, LastErrorText);
        end;
        OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);

        CollabLog.LogEvent("AMC Source Type"::Request, RequestNo, 0, "AMC Collab Entry Type"::OrderUnlocked, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), RequestCancelledDescriptionLbl, CreateGuid());
    end;

    /// <summary>
    /// Closes an applied request, revokes its tokens and clears its order lock within the caller's apply context.
    /// </summary>
    /// <param name="VendorRequest">The request to close and stamp with the closure time.</param>
    /// <param name="PurchaseHeader">The order whose active request and collaboration status are updated.</param>
    procedure CloseAfterApply(var VendorRequest: Record "AMC Vendor Request"; var PurchaseHeader: Record "Purchase Header")
    var
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        LinkRevokedOnCloseDescriptionLbl: Label 'Vendor request was closed.';
    begin
        this.SetStatus(VendorRequest, VendorRequest.Status::Closed);
        AccessTokenMgt.RevokeRequestTokens(VendorRequest."No.", LinkRevokedOnCloseDescriptionLbl);
        VendorRequest.Validate("Closed Date Time", CurrentDateTime());
        VendorRequest.Modify(true);

        PurchaseHeader.Validate("AMC Active Request No.", '');
        PurchaseHeader.Validate("AMC Collaboration Status", VendorRequest.Status);
        PurchaseHeader.Modify(true);
    end;

    /// <summary>
    /// Sends or resends a link for a draft or awaiting-vendor request, superseding old links on resend and updating send status.
    /// Email handoff can commit through the standard email implementation; this is not an atomic send-and-status operation.
    /// </summary>
    /// <param name="VendorRequest">The request to reread and update after notification handoff.</param>
    procedure Send(var VendorRequest: Record "AMC Vendor Request")
    var
        PurchaseHeader: Record "Purchase Header";
        AccessTokenMgt: Codeunit "AMC Access Token Mgt";
        CollabLog: Codeunit "AMC Collab Log";
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
        VendorNotification: Codeunit "AMC Vendor Notification";
        PreviousPurchaseOrderNo: Code[20];
        PreviousRequestNo: Code[20];
        RequestNo: Code[20];
        LastErrorText: Text;
        InvalidSendStatusErr: Label 'Vendor request %1 must be Draft or Awaiting Vendor before a link can be sent.', Comment = '%1 = vendor request number';
        RequestSentDescriptionLbl: Label 'Vendor request sent to vendor.';
        RequestSendFailedErr: Label 'The vendor request send status could not be updated: %1', Comment = '%1 = original error detail';
    begin
        RequestNo := VendorRequest."No.";
        // Preserve isolation in nested buffers; this transaction state ends at the standard Email commit.
        VendorRequest.LockTable();
        if not VendorRequest.Get(RequestNo) then
            Error(this.RequiredRecordNotFoundErr, VendorRequest.TableCaption());
        if not (VendorRequest.Status in [VendorRequest.Status::Draft, VendorRequest.Status::"Awaiting Vendor"]) then
            Error(InvalidSendStatusErr, VendorRequest."No.");
        if VendorRequest.Status = VendorRequest.Status::"Awaiting Vendor" then
            AccessTokenMgt.Supersede(VendorRequest."No.");

        VendorNotification.Send(VendorRequest."No.");
        if VendorRequest.Status = VendorRequest.Status::Draft then begin
            this.SetStatus(VendorRequest, VendorRequest.Status::"Awaiting Vendor");
            CollabLog.LogEvent("AMC Source Type"::Request, VendorRequest."No.", 0, "AMC Collab Entry Type"::RequestSent, "AMC Actor Type"::Buyer, '', CopyStr(UserId(), 1, 50), RequestSentDescriptionLbl, CreateGuid());
        end;
        VendorRequest.Validate("Sent Date Time", CurrentDateTime());
        VendorRequest.Modify(true);
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorRequest."Purchase Order No.") then
            Error(this.RequiredRecordNotFoundErr, PurchaseHeader.TableCaption());
        OrderLockMgt.SetSuppressionContext(PurchaseHeader."No.", VendorRequest."No.", PreviousPurchaseOrderNo, PreviousRequestNo);
        if not this.TryUpdatePurchaseOrderCollaborationStatus(PurchaseHeader, VendorRequest.Status) then begin
            LastErrorText := GetLastErrorText();
            OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
            Error(RequestSendFailedErr, LastErrorText);
        end;
        OrderLockMgt.RestoreSuppressionContext(PreviousPurchaseOrderNo, PreviousRequestNo);
    end;

    [TryFunction]
    local procedure TryUpdatePurchaseOrderCollaborationStatus(var PurchaseHeader: Record "Purchase Header"; RequestStatus: Enum "AMC Request Status")
    begin
        PurchaseHeader.Validate("AMC Collaboration Status", RequestStatus);
        PurchaseHeader.Modify(true);
    end;

    [TryFunction]
    local procedure TryClearPurchaseOrderRequest(var PurchaseHeader: Record "Purchase Header"; RequestStatus: Enum "AMC Request Status")
    begin
        PurchaseHeader.Validate("AMC Active Request No.", '');
        PurchaseHeader.Validate("AMC Collaboration Status", RequestStatus);
        PurchaseHeader.Modify(true);
    end;

  /// <summary>
  /// Checks the request state machine and persists an allowed transition with the modify trigger.
  /// </summary>
  /// <param name="VendorRequest">The request buffer to transition and persist.</param>
  /// <param name="NewStatus">The permitted next status; invalid transitions raise an error.</param>
  procedure SetStatus(var VendorRequest: Record "AMC Vendor Request"; NewStatus: Enum "AMC Request Status")
  var
    VCHReq0005Err: Label 'Vendor request status cannot change from %1 to %2.', Comment = '%1 = current request status, %2 = requested request status';
  begin
    if not this.IsStatusTransitionAllowed(VendorRequest.Status, NewStatus) then
      Error(VCHReq0005Err, VendorRequest.Status, NewStatus);

    VendorRequest.Validate(Status, NewStatus);
    VendorRequest.Modify(true);
  end;

  local procedure IsStatusTransitionAllowed(CurrentStatus: Enum "AMC Request Status"; NewStatus: Enum "AMC Request Status"): Boolean
  begin
    case CurrentStatus of
      CurrentStatus::Draft:
        exit(NewStatus in [NewStatus::"Awaiting Vendor", NewStatus::Cancelled]);
      CurrentStatus::"Awaiting Vendor":
        exit(NewStatus in [NewStatus::"Vendor Responded", NewStatus::Cancelled]);
      CurrentStatus::"Vendor Responded":
        exit(NewStatus in [NewStatus::"In Review", NewStatus::Closed, NewStatus::Cancelled]);
      CurrentStatus::"In Review":
        exit(NewStatus in [NewStatus::Closed, NewStatus::Cancelled]);
    end;
    exit(false);
  end;

    local procedure VerifyPurchaseOrderCanBeCancelled(PurchaseHeader: Record "Purchase Header"; VendorRequest: Record "AMC Vendor Request")
    var
        NoActiveRequestErr: Label 'Purchase order %1 does not have an active vendor request.', Comment = '%1 = purchase order number';
        TerminalRequestErr: Label 'Vendor request %1 is already terminal and cannot be cancelled.', Comment = '%1 = vendor request number';
    begin
        if PurchaseHeader."AMC Active Request No." = '' then
            Error(NoActiveRequestErr, PurchaseHeader."No.");

        if VendorRequest."Purchase Order No." <> PurchaseHeader."No." then
            Error(NoActiveRequestErr, PurchaseHeader."No.");

        if VendorRequest.Status in [VendorRequest.Status::Closed, VendorRequest.Status::Cancelled] then
            Error(TerminalRequestErr, VendorRequest."No.");
    end;

    local procedure VerifyPurchaseOrderCanCreateRequest(PurchaseHeader: Record "Purchase Header")
    var
        VCHReq0004Err: Label 'Purchase order %1 must be open. Use the Reopen action before creating a vendor request.', Comment = '%1 = purchase order number';
    begin
        if PurchaseHeader.Status <> PurchaseHeader.Status::Open then
            Error(VCHReq0004Err, PurchaseHeader."No.");
    end;

    local procedure VerifyCollaborationEnabled(CollaborationSetup: Record "AMC Collaboration Setup")
    var
        CollaborationSetupPage: Page "AMC Collaboration Setup";
        CollaborationDisabledError: ErrorInfo;
        VCHAut0001Err: Label 'Vendor collaboration is not enabled in Vendor Collaboration Setup.';
        OpenCollaborationSetupLbl: Label 'Open %1', Comment = '%1 = page caption';
    begin
        if not CollaborationSetup.Enabled then begin
            CollaborationDisabledError.Message(VCHAut0001Err);
            CollaborationDisabledError.PageNo(Page::"AMC Collaboration Setup");
            CollaborationDisabledError.RecordId(CollaborationSetup.RecordId());
            CollaborationDisabledError.AddNavigationAction(StrSubstNo(OpenCollaborationSetupLbl, CollaborationSetupPage.Caption()));
            Error(CollaborationDisabledError);
        end;
    end;

    local procedure VerifyVendorCollaborationEnabled(Vendor: Record Vendor)
    var
        VendorCard: Page "Vendor Card";
        VendorCollaborationDisabledError: ErrorInfo;
        VCHAut0002Err: Label 'Vendor %1 is not enabled for vendor collaboration.', Comment = '%1 = vendor number';
        OpenVendorCardLbl: Label 'Open %1', Comment = '%1 = page caption';
    begin
        if not Vendor."AMC Collaboration Enabled" then begin
            VendorCollaborationDisabledError.Message(StrSubstNo(VCHAut0002Err, Vendor."No."));
            VendorCollaborationDisabledError.PageNo(Page::"Vendor Card");
            VendorCollaborationDisabledError.RecordId(Vendor.RecordId());
            VendorCollaborationDisabledError.AddNavigationAction(StrSubstNo(OpenVendorCardLbl, VendorCard.Caption()));
            Error(VendorCollaborationDisabledError);
        end;
    end;

    local procedure VerifyNoActiveRequest(PurchaseOrderNo: Code[20])
    var
        VendorRequest: Record "AMC Vendor Request";
        VCHReq0001Err: Label 'Purchase order %1 already has active vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        VendorRequest.SetRange("Purchase Order No.", PurchaseOrderNo);
        VendorRequest.SetFilter(Status, '%1|%2|%3|%4', VendorRequest.Status::Draft, VendorRequest.Status::"Awaiting Vendor", VendorRequest.Status::"Vendor Responded", VendorRequest.Status::"In Review");
        VendorRequest.SetLoadFields("No.");
        if VendorRequest.FindFirst() then // todo: use isempty?
            Error(VCHReq0001Err, PurchaseOrderNo, VendorRequest."No.");
    end;

    local procedure CreateVendorRequest(var VendorRequest: Record "AMC Vendor Request"; RequestNo: Code[20]; PurchaseHeader: Record "Purchase Header"; Vendor: Record Vendor; CollaborationSetup: Record "AMC Collaboration Setup")
    begin
        VendorRequest.Init();
        VendorRequest.Validate("No.", RequestNo);
        VendorRequest.InitRecord();
        VendorRequest.Validate("Vendor No.", PurchaseHeader."Buy-from Vendor No.");
        VendorRequest.Validate("Purchase Order No.", PurchaseHeader."No.");
        VendorRequest.Validate("Purchaser Code", PurchaseHeader."Purchaser Code");
        VendorRequest.Validate("Assigned User ID", PurchaseHeader."Assigned User ID");
        VendorRequest.Validate("Currency Code", PurchaseHeader."Currency Code");
        VendorRequest.Validate("Language Code", this.GetRequestLanguageCode(Vendor));
        VendorRequest.Validate("Response Deadline", WorkDate() + this.GetResponseDays(Vendor, CollaborationSetup));
        VendorRequest.Insert(true);
    end;

    local procedure GetRequestLanguageCode(Vendor: Record Vendor): Code[10]
    var
        Language: Codeunit Language;
    begin
        if Vendor."Language Code" <> '' then
            exit(Vendor."Language Code");

        exit(Language.GetLanguageCode(Language.GetDefaultApplicationLanguageId()));
    end;

    local procedure GetResponseDays(Vendor: Record Vendor; CollaborationSetup: Record "AMC Collaboration Setup"): Integer
    begin
        if Vendor."AMC Response Days" <> 0 then
            exit(Vendor."AMC Response Days");

        exit(CollaborationSetup."Default Response Days");
    end;

    local procedure CreateVendorRequestLines(var VendorRequestLine: Record "AMC Vendor Request Line"; RequestNo: Code[20]; PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line") LineCount: Integer
    begin
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetLoadFields("Line No.", "No.", "Variant Code", Description, "Location Code", "Unit of Measure Code", Quantity, "Requested Receipt Date");
        if PurchaseLine.FindSet() then
            repeat
                VendorRequestLine.Init();
                VendorRequestLine.Validate("Request No.", RequestNo);
                VendorRequestLine.Validate("Line No.", PurchaseLine."Line No.");
                VendorRequestLine.Validate("Purchase Line No.", PurchaseLine."Line No.");
                VendorRequestLine.Validate("Item No.", PurchaseLine."No.");
                VendorRequestLine.Validate("Variant Code", PurchaseLine."Variant Code");
                VendorRequestLine.Validate(Description, PurchaseLine.Description);
                VendorRequestLine.Validate("Location Code", PurchaseLine."Location Code");
                VendorRequestLine.Validate("Unit of Measure Code", PurchaseLine."Unit of Measure Code");
                VendorRequestLine.Validate("Requested Quantity", PurchaseLine.Quantity);
                VendorRequestLine.Validate("Requested Delivery Date", PurchaseLine."Requested Receipt Date");
                VendorRequestLine.Validate("Confirmed Quantity", 0);
                VendorRequestLine.Validate("Outstanding Quantity", PurchaseLine.Quantity);
                VendorRequestLine.Validate(Status, VendorRequestLine.Status::Open);
                VendorRequestLine.Insert(false);
                LineCount += 1;
            until PurchaseLine.Next() = 0;
        exit(LineCount);
    end;

    var
        RequiredRecordNotFoundErr: Label 'The %1 record required for the vendor request could not be found. Refresh the document and try again.', Comment = '%1 = table caption';
}
