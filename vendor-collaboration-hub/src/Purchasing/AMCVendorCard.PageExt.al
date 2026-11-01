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
            }
            field("AMC Portal Contact E-Mail"; Rec."AMC Portal Contact E-Mail")
            {
                ApplicationArea = All;
            }
            field("AMC Response Days"; Rec."AMC Response Days")
            {
                ApplicationArea = All;
            }
        }
    }
}
