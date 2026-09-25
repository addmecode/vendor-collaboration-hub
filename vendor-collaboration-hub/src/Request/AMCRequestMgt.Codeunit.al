namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

codeunit 50100 "AMC Request Mgt"
{
    Permissions = tabledata "Purchase Header" = M;

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
        PurchaseHeader.LockTable();
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, OrderNo);

        this.VerifyPurchaseOrderCanCreateRequest(PurchaseHeader);

        CollaborationSetup.GetSetup();
        this.VerifyCollaborationEnabled(CollaborationSetup);

        Vendor.Get(PurchaseHeader."Buy-from Vendor No.");
        this.VerifyVendorCollaborationEnabled(Vendor);
        this.VerifyNoActiveRequest(PurchaseHeader."No.");

        RequestNo := NoSeries.GetNextNo(CollaborationSetup."Request Nos.");
        this.CreateVendorRequest(VendorRequest, RequestNo, PurchaseHeader);
        LineCount := this.CreateVendorRequestLines(VendorRequestLine, RequestNo, PurchaseHeader, PurchaseLine);

        //todo: move to a separate function?
        PurchaseHeader."AMC Active Request No." := RequestNo;
        PurchaseHeader."AMC Collaboration Status" := VendorRequest.Status;
        PurchaseHeader.Modify(true);

        CollabLog.LogEvent("AMC Source Type"::Request, RequestNo, 0, "AMC Collab Entry Type"::RequestCreated, "AMC Actor Type"::Buyer, '', UserId(), false, RequestCreatedDescriptionLbl, CreateGuid());
        Telemetry.LogRequestCreated(RequestNo, PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."No.", LineCount);

        exit(RequestNo);
    end;

  procedure SetStatus(var VendorRequest: Record "AMC Vendor Request"; NewStatus: Enum "AMC Request Status")
  var
    VCHReq0005Err: Label 'Vendor request status cannot change from %1 to %2.', Comment = '%1 = current request status, %2 = requested request status';
  begin
    if not this.IsStatusTransitionAllowed(VendorRequest.Status, NewStatus) then
      Error(VCHReq0005Err, VendorRequest.Status, NewStatus);

    VendorRequest.Status := NewStatus;
    VendorRequest.Modify(true);
  end;

  local procedure IsStatusTransitionAllowed(CurrentStatus: Enum "AMC Request Status"; NewStatus: Enum "AMC Request Status"): Boolean
  begin
    case CurrentStatus of
      CurrentStatus::Draft:
        exit(NewStatus in [NewStatus::Sent, NewStatus::Cancelled]);
      CurrentStatus::Sent:
        exit(NewStatus in [NewStatus::"Awaiting Vendor", NewStatus::Cancelled]);
      CurrentStatus::"Awaiting Vendor":
        exit(NewStatus in [NewStatus::"Vendor Responded", NewStatus::Cancelled]);
      CurrentStatus::"Vendor Responded":
        exit(NewStatus in [NewStatus::"In Review", NewStatus::Closed, NewStatus::Cancelled]);
      CurrentStatus::"In Review":
        exit(NewStatus = NewStatus::Closed);
    end;
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
        VCHAut0001Err: Label 'Vendor collaboration is not enabled in Vendor Collaboration Setup.';
    begin
        if not CollaborationSetup.Enabled then
            Error(VCHAut0001Err);
    end;

    local procedure VerifyVendorCollaborationEnabled(Vendor: Record Vendor)
    var
        VCHAut0002Err: Label 'Vendor %1 is not enabled for vendor collaboration.', Comment = '%1 = vendor number';
    begin
        if not Vendor."AMC Collaboration Enabled" then
            Error(VCHAut0002Err, Vendor."No.");
    end;

    local procedure VerifyNoActiveRequest(PurchaseOrderNo: Code[20])
    var
        VendorRequest: Record "AMC Vendor Request";
        VCHReq0001Err: Label 'Purchase order %1 already has active vendor request %2.', Comment = '%1 = purchase order number, %2 = vendor request number';
    begin
        VendorRequest.SetRange("Purchase Order No.", PurchaseOrderNo);
        VendorRequest.SetFilter(Status, '%1|%2|%3|%4|%5', VendorRequest.Status::Draft, VendorRequest.Status::Sent, VendorRequest.Status::"Awaiting Vendor", VendorRequest.Status::"Vendor Responded", VendorRequest.Status::"In Review");
        if VendorRequest.FindFirst() then // todo: use isempty?
            Error(VCHReq0001Err, PurchaseOrderNo, VendorRequest."No.");
    end;

    local procedure CreateVendorRequest(var VendorRequest: Record "AMC Vendor Request"; RequestNo: Code[20]; PurchaseHeader: Record "Purchase Header")
    begin
        VendorRequest.Init();
        VendorRequest."No." := RequestNo;
        VendorRequest."Vendor No." := PurchaseHeader."Buy-from Vendor No.";
        VendorRequest."Purchase Order No." := PurchaseHeader."No.";
        VendorRequest."Purchaser Code" := PurchaseHeader."Purchaser Code";
        VendorRequest."Assigned User ID" := PurchaseHeader."Assigned User ID";
        VendorRequest."Currency Code" := PurchaseHeader."Currency Code";
        VendorRequest.Status := VendorRequest.Status::Draft;
        VendorRequest.Insert(true);
    end;

    local procedure CreateVendorRequestLines(var VendorRequestLine: Record "AMC Vendor Request Line"; RequestNo: Code[20]; PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line") LineCount: Integer
    begin
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetLoadFields("Line No.", "No.", "Variant Code", Description, "Location Code", "Unit of Measure Code", Quantity, "Requested Receipt Date");
        if PurchaseLine.FindSet() then
            repeat
                VendorRequestLine.Init();
                VendorRequestLine."Request No." := RequestNo;
                VendorRequestLine."Line No." := PurchaseLine."Line No.";
                VendorRequestLine."Purchase Line No." := PurchaseLine."Line No.";
                VendorRequestLine."Item No." := PurchaseLine."No.";
                VendorRequestLine."Variant Code" := PurchaseLine."Variant Code";
                VendorRequestLine.Description := PurchaseLine.Description;
                VendorRequestLine."Location Code" := PurchaseLine."Location Code";
                VendorRequestLine."Unit of Measure Code" := PurchaseLine."Unit of Measure Code";
                VendorRequestLine."Requested Quantity" := PurchaseLine.Quantity;
                VendorRequestLine."Requested Delivery Date" := PurchaseLine."Requested Receipt Date";
                VendorRequestLine."Confirmed Quantity" := 0;
                VendorRequestLine."Outstanding Quantity" := PurchaseLine.Quantity;
                VendorRequestLine.Status := VendorRequestLine.Status::Open;
                VendorRequestLine.Insert(true);
                LineCount += 1;
            until PurchaseLine.Next() = 0;
    end;
}
