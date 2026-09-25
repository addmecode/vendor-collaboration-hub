namespace Addmecode.VendorCollaborationHub;

enum 50103 "AMC Proposal Line Type"
{
    Extensible = true;

    value(0; Confirm)
    {
        Caption = 'Confirm';
    }
    value(1; "Change Quantity")
    {
        Caption = 'Change Quantity';
    }
    value(2; "Change Date")
    {
        Caption = 'Change Date';
    }
    value(3; "Split Delivery")
    {
        Caption = 'Split Delivery';
    }
    value(4; "Substitute Item")
    {
        Caption = 'Substitute Item';
    }
    value(5; "Cancel Remainder")
    {
        Caption = 'Cancel Remainder';
    }
}
