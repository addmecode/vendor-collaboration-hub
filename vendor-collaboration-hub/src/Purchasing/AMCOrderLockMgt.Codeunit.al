namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Guards purchase orders with active requests and maintains session-local, request-scoped suppression for allowed changes.
/// </summary>
codeunit 50120 "AMC Order Lock Mgt"
{
    Permissions = tabledata "Purchase Header" = r;
    SingleInstance = true;

    /// <summary>
    /// Rejects modification of a persisted order with an active request unless the matching suppression context allows it.
    /// </summary>
    /// <param name="PurchaseHeader">Identifies the purchase document to check.</param>
    procedure VerifyPurchaseHeaderCanBeModified(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, true);
    end;

    /// <summary>
    /// Rejects deletion of an order with an active request, even within a suppression context.
    /// </summary>
    /// <param name="PurchaseHeader">Identifies the purchase document to check.</param>
    procedure VerifyPurchaseHeaderCanBeDeleted(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, false);
    end;

    /// <summary>
    /// Checks the parent order lock before a line change, allowing only matching suppression.
    /// </summary>
    /// <param name="PurchaseLine">Identifies the line's parent purchase document.</param>
    procedure VerifyPurchaseLineCanBeModified(PurchaseLine: Record "Purchase Line")
    begin
        this.VerifyPurchaseLineIsNotLocked(PurchaseLine, true);
    end;

    /// <summary>
    /// Checks the parent order lock before line deletion without allowing suppression.
    /// </summary>
    /// <param name="PurchaseLine">Identifies the line's parent purchase document.</param>
    procedure VerifyPurchaseLineCanBeDeleted(PurchaseLine: Record "Purchase Line")
    begin
        this.VerifyPurchaseLineIsNotLocked(PurchaseLine, false);
    end;

    /// <summary>
    /// Rejects release of an order with an active request unless the matching suppression context allows it.
    /// </summary>
    /// <param name="PurchaseHeader">Identifies the purchase document to check.</param>
    procedure VerifyPurchaseOrderCanBeReleased(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, true);
    end;

    /// <summary>
    /// Rejects posting of an order with an active request regardless of suppression.
    /// </summary>
    /// <param name="PurchaseHeader">Identifies the purchase document to check.</param>
    procedure VerifyPurchaseOrderCanBePosted(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, false);
    end;

    /// <summary>
    /// Loads the proposal's order and requires its active request to match the proposal request.
    /// </summary>
    /// <param name="VendorProposal">Supplies the expected order and request identity.</param>
    /// <param name="PurchaseHeader">Receives the persisted purchase order.</param>
    procedure AssertLockedBy(VendorProposal: Record "AMC Vendor Proposal"; var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseOrderNotLockedByRequestErr: Label 'VCH-APL-0003: Purchase order %1 is not locked by vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorProposal."Purchase Order No.") then
            Error(PurchaseOrderNotLockedByRequestErr, VendorProposal."Purchase Order No.", VendorProposal."Request No.");

        if PurchaseHeader."AMC Active Request No." <> VendorProposal."Request No." then
            Error(PurchaseOrderNotLockedByRequestErr, PurchaseHeader."No.", VendorProposal."Request No.");
    end;

    /// <summary>
    /// Replaces the session-local suppression scope and returns the previous scope for mandatory restoration by the caller.
    /// </summary>
    /// <param name="PurchaseOrderNo">The order allowed to undergo suppressible operations.</param>
    /// <param name="RequestNo">The active request that must match that order.</param>
    /// <param name="PreviousPurchaseOrderNo">Receives the previously suppressed order number.</param>
    /// <param name="PreviousRequestNo">Receives the previously suppressed request number.</param>
    procedure SetSuppressionContext(PurchaseOrderNo: Code[20]; RequestNo: Code[20]; var PreviousPurchaseOrderNo: Code[20]; var PreviousRequestNo: Code[20])
    begin
        PreviousPurchaseOrderNo := this.SuppressedPurchaseOrderNo;
        PreviousRequestNo := this.SuppressedRequestNo;
        this.SuppressedPurchaseOrderNo := PurchaseOrderNo;
        this.SuppressedRequestNo := RequestNo;
    end;

    /// <summary>
    /// Reads the current session-local suppression scope without changing it.
    /// </summary>
    /// <param name="PurchaseOrderNo">Receives the suppressed order number, or empty when unset.</param>
    /// <param name="RequestNo">Receives the suppressed request number, or empty when unset.</param>
    procedure GetSuppressionContext(var PurchaseOrderNo: Code[20]; var RequestNo: Code[20])
    begin
        PurchaseOrderNo := this.SuppressedPurchaseOrderNo;
        RequestNo := this.SuppressedRequestNo;
    end;

    /// <summary>
    /// Restores a saved suppression scope after either a successful or failed operation.
    /// </summary>
    /// <param name="PreviousPurchaseOrderNo">The previously saved order number.</param>
    /// <param name="PreviousRequestNo">The previously saved request number.</param>
    procedure RestoreSuppressionContext(PreviousPurchaseOrderNo: Code[20]; PreviousRequestNo: Code[20])
    begin
        this.SuppressedPurchaseOrderNo := PreviousPurchaseOrderNo;
        this.SuppressedRequestNo := PreviousRequestNo;
    end;

    local procedure VerifyPurchaseLineIsNotLocked(PurchaseLine: Record "Purchase Line"; AllowSuppression: Boolean)
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        if PurchaseLine."Document Type" <> PurchaseLine."Document Type"::Order then
            exit;

        if not PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            exit;

        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, AllowSuppression);
    end;

    local procedure VerifyPurchaseOrderIsNotLocked(PurchaseHeader: Record "Purchase Header"; AllowSuppression: Boolean)
    var
        PersistedPurchaseHeader: Record "Purchase Header";
        PurchaseOrderLockedErr: Label 'Purchase order %1 is locked by active vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::Order then
            exit;

        PersistedPurchaseHeader.SetLoadFields("Document Type", "No.", "AMC Active Request No.");
        if not PersistedPurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.") then
            exit;

        if PersistedPurchaseHeader."AMC Active Request No." = '' then
            exit;

        if AllowSuppression and this.IsSuppressed(PersistedPurchaseHeader) then
            exit;

        Error(PurchaseOrderLockedErr, PersistedPurchaseHeader."No.", PersistedPurchaseHeader."AMC Active Request No.");
    end;

    local procedure IsSuppressed(PurchaseHeader: Record "Purchase Header"): Boolean
    begin
        exit((this.SuppressedPurchaseOrderNo <> '') and
             (this.SuppressedRequestNo <> '') and
             (this.SuppressedPurchaseOrderNo = PurchaseHeader."No.") and
             (this.SuppressedRequestNo = PurchaseHeader."AMC Active Request No."));
    end;

    var
        SuppressedPurchaseOrderNo: Code[20];
        SuppressedRequestNo: Code[20];
}
