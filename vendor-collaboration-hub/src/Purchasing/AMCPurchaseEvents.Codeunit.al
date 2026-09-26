namespace Addmecode.VendorCollaborationHub;

using Microsoft.Inventory.Posting;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;

codeunit 50107 "AMC Purchase Events"
{
    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeModifyEvent', '', false, false)]
    local procedure OnBeforeModifyPurchaseHeader(var Rec: Record "Purchase Header"; var xRec: Record "Purchase Header"; RunTrigger: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseHeaderCanBeModified(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure OnBeforeDeletePurchaseHeader(var Rec: Record "Purchase Header"; RunTrigger: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseHeaderCanBeDeleted(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeModifyEvent', '', false, false)]
    local procedure OnBeforeModifyPurchaseLine(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line"; RunTrigger: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseLineCanBeModified(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeInsertEvent', '', false, false)]
    local procedure OnBeforeInsertPurchaseLine(var Rec: Record "Purchase Line"; RunTrigger: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseLineCanBeModified(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure OnBeforeDeletePurchaseLine(var Rec: Record "Purchase Line"; RunTrigger: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseLineCanBeDeleted(Rec);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", 'OnBeforeReleasePurchaseDoc', '', false, false)]
    local procedure OnBeforeReleasePurchaseDoc(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean; var SkipCheckReleaseRestrictions: Boolean; var IsHandled: Boolean; SkipWhseRequestOperations: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseOrderCanBeReleased(PurchaseHeader);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostPurchaseDoc', '', false, false)]
    local procedure OnBeforePostPurchaseDoc(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean; CommitIsSupressed: Boolean; var HideProgressWindow: Boolean; var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line"; var IsHandled: Boolean)
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseOrderCanBePosted(PurchaseHeader);
    end;
}
