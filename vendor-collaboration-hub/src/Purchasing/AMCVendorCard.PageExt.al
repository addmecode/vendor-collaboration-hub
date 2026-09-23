namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Vendor;

pageextension 50102 "AMC Vendor Card" extends "Vendor Card"
{
    layout
    {
        addlast(General)
        {
            field("AMC Collaboration Enabled"; Rec."AMC Collaboration Enabled")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this vendor can participate in vendor collaboration.';
            }
        }
    }
}
