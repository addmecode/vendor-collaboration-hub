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
            field("AMC Portal Contact E-Mail"; Rec."AMC Portal Contact E-Mail")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the email address to which vendor collaboration links are sent. If blank, the vendor email address is used.';
            }
            field("AMC Response Days"; Rec."AMC Response Days")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the number of days this vendor has to respond. Leave blank to use the default response days from Vendor Collaboration Setup.';
            }
        }
    }
}
