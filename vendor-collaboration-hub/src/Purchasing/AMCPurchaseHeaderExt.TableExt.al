namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

tableextension 50100 "AMC Purchase Header Ext" extends "Purchase Header"
{
    fields
    {
        field(50100; "AMC Collaboration Status"; Enum "AMC Request Status")
        {
            Caption = 'Collaboration Status';
            ToolTip = 'Specifies the current vendor collaboration status for this purchase order.';
            DataClassification = CustomerContent;
        }
        field(50101; "AMC Active Request No."; Code[20])
        {
            Caption = 'Active Request No.';
            ToolTip = 'Specifies the active vendor request for this purchase order.';
            DataClassification = CustomerContent;
            TableRelation = "AMC Vendor Request";
        }
    }
}
