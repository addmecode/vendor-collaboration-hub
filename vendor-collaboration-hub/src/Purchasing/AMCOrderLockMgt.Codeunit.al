namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

codeunit 50120 "AMC Order Lock Mgt"
{
    SingleInstance = true;

    procedure VerifyPurchaseHeaderCanBeModified(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, true);
    end;

    procedure VerifyPurchaseHeaderCanBeDeleted(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, false);
    end;

    procedure VerifyPurchaseLineCanBeModified(PurchaseLine: Record "Purchase Line")
    begin
        this.VerifyPurchaseLineIsNotLocked(PurchaseLine, true);
    end;

    procedure VerifyPurchaseLineCanBeDeleted(PurchaseLine: Record "Purchase Line")
    begin
        this.VerifyPurchaseLineIsNotLocked(PurchaseLine, false);
    end;

    procedure VerifyPurchaseOrderCanBeReleased(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, true);
    end;

    procedure VerifyPurchaseOrderCanBePosted(PurchaseHeader: Record "Purchase Header")
    begin
        this.VerifyPurchaseOrderIsNotLocked(PurchaseHeader, false);
    end;

    procedure AssertLockedBy(VendorProposal: Record "AMC Vendor Proposal"; var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseOrderNotLockedByRequestErr: Label 'VCH-APL-0003: Purchase order %1 is not locked by vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, VendorProposal."Purchase Order No.") then
            Error(PurchaseOrderNotLockedByRequestErr, VendorProposal."Purchase Order No.", VendorProposal."Request No.");

        if PurchaseHeader."AMC Active Request No." <> VendorProposal."Request No." then
            Error(PurchaseOrderNotLockedByRequestErr, PurchaseHeader."No.", VendorProposal."Request No.");
    end;

    procedure SetSuppressionContext(PurchaseOrderNo: Code[20]; RequestNo: Code[20]; var PreviousPurchaseOrderNo: Code[20]; var PreviousRequestNo: Code[20])
    begin
        PreviousPurchaseOrderNo := this.SuppressedPurchaseOrderNo;
        PreviousRequestNo := this.SuppressedRequestNo;
        this.SuppressedPurchaseOrderNo := PurchaseOrderNo;
        this.SuppressedRequestNo := RequestNo;
    end;

    procedure GetSuppressionContext(var PurchaseOrderNo: Code[20]; var RequestNo: Code[20])
    begin
        PurchaseOrderNo := this.SuppressedPurchaseOrderNo;
        RequestNo := this.SuppressedRequestNo;
    end;

    procedure RestoreSuppressionContext(PreviousPurchaseOrderNo: Code[20]; PreviousRequestNo: Code[20])
    begin
        this.SuppressedPurchaseOrderNo := PreviousPurchaseOrderNo;
        this.SuppressedRequestNo := PreviousRequestNo;
    end;

    local procedure VerifyPurchaseLineIsNotLocked(PurchaseLine: Record "Purchase Line"; AllowSuppression: Boolean)
    var
        PurchaseHeader: Record "Purchase Header";
    begin
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
