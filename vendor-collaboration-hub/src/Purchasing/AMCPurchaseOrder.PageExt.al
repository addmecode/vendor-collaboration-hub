namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

pageextension 50100 "AMC Purchase Order" extends "Purchase Order"
{
    layout
    {
        addlast(General)
        {
            field(AMCActiveRequestNo; Rec."AMC Active Request No.")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the active vendor request for this purchase order.';
            }
            field(AMCCollaborationStatus; Rec."AMC Collaboration Status")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the current vendor collaboration status for this purchase order.';
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(AMCCreateVendorRequest)
            {
                ApplicationArea = All;
                Caption = 'Send to Vendor Collaboration';
                Image = SendTo;
                ToolTip = 'Creates a vendor request from this purchase order.';

                trigger OnAction()
                begin
                    this.CreateVendorRequest();
                end;
            }
        }
    }

    local procedure CreateVendorRequest()
    var
        VendorRequest: Record "AMC Vendor Request";
        RequestMgt: Codeunit "AMC Request Mgt";
        RequestNo: Code[20];
        OpenCreatedVendorRequestQst: Label 'Vendor request %1 has been created. Do you want to open it?', Comment = '%1 = vendor request number';
    begin
        RequestNo := RequestMgt.CreateFromOrder(Rec);
        CurrPage.Update(false);
        if not Confirm(OpenCreatedVendorRequestQst, false, RequestNo) then
            exit;

        VendorRequest.Get(RequestNo);
        Page.Run(Page::"AMC Vendor Request", VendorRequest);
    end;
}
