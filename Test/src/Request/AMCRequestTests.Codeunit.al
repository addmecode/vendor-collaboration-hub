namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using System.TestLibraries.Utilities;

codeunit 50131 "AMC Request Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GivenNewRequestAndLine_WhenInitialized_ThenDefaultStatusesAreUsed()
    var
        TempVendorRequest: Record "AMC Vendor Request" temporary;
        TempVendorRequestLine: Record "AMC Vendor Request Line" temporary;
    begin
        // Given
        TempVendorRequest.Init();
        TempVendorRequestLine.Init();

        // When

        // Then
        this.Assert.AreEqual(TempVendorRequest.Status::Draft, TempVendorRequest.Status, 'A new vendor request must start as Draft.');
        this.Assert.AreEqual(TempVendorRequestLine.Status::Open, TempVendorRequestLine.Status, 'A new vendor request line must start as Open.');
    end;

    [Test]
    procedure GivenRequestWithLine_WhenRequestIsDeleted_ThenLineIsDeleted()
    var
        VendorRequest: Record "AMC Vendor Request";
        VendorRequestLine: Record "AMC Vendor Request Line";
        RequestNo: Code[20];
    begin
        // Given
        RequestNo := this.CreateRequestNo();
        this.InsertVendorRequest(VendorRequest, RequestNo);
        this.InsertVendorRequest(VendorRequestLine, RequestNo);

        // When
        VendorRequest.Delete(true);

        // Then
        VendorRequestLine.SetRange("Request No.", RequestNo);
        this.Assert.IsTrue(VendorRequestLine.IsEmpty(), 'Deleting a vendor request must delete its lines.');
    end;

    local procedure CreateRequestNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure InsertVendorRequest(var VendorRequest: Record "AMC Vendor Request"; RequestNo: Code[20])
    begin
        VendorRequest.Init();
        VendorRequest."No." := RequestNo;
        VendorRequest.Insert();
    end;

    local procedure InsertVendorRequest(var VendorRequestLine: Record "AMC Vendor Request Line"; RequestNo: Code[20])
    begin
        VendorRequestLine.Init();
        VendorRequestLine."Request No." := RequestNo;
        VendorRequestLine."Line No." := 10000;
        VendorRequestLine.Insert();
    end;
}
