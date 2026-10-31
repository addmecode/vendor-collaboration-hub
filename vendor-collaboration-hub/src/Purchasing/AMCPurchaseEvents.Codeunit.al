namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;

codeunit 50107 "AMC Purchase Events"
{
    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", OnBeforeModifyEvent, '', false, false)]
    local procedure "Purchase Header_OnBeforeModifyEvent"(var Rec: Record "Purchase Header")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseHeaderCanBeModified(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", OnBeforeDeleteEvent, '', false, false)]
    local procedure "Purchase Header_OnBeforeDeleteEvent"(var Rec: Record "Purchase Header")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseHeaderCanBeDeleted(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", OnBeforeModifyEvent, '', false, false)]
    local procedure "Purchase Line_OnBeforeModifyEvent"(var Rec: Record "Purchase Line")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseLineCanBeModified(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", OnBeforeInsertEvent, '', false, false)]
    local procedure "Purchase Line_OnBeforeInsertEvent"(var Rec: Record "Purchase Line")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseLineCanBeModified(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", OnBeforeDeleteEvent, '', false, false)]
    local procedure "Purchase Line_OnBeforeDeleteEvent"(var Rec: Record "Purchase Line")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseLineCanBeDeleted(Rec);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", OnBeforeReleasePurchaseDoc, '', false, false)]
    local procedure "Release Purchase Document_OnBeforeReleasePurchaseDoc"(var PurchaseHeader: Record "Purchase Header")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseOrderCanBeReleased(PurchaseHeader);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", OnBeforePostPurchaseDoc, '', false, false)]
    local procedure "Purch.-Post_OnBeforePostPurchaseDoc"(var PurchaseHeader: Record "Purchase Header")
    var
        OrderLockMgt: Codeunit "AMC Order Lock Mgt";
    begin
        OrderLockMgt.VerifyPurchaseOrderCanBePosted(PurchaseHeader);
    end;
}
