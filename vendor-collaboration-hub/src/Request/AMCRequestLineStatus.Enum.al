namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Defines the confirmation and outstanding-quantity states of a request line.
/// </summary>
enum 50101 "AMC Request Line Status"
{
    Extensible = true;

    value(0; Open)
    {
        Caption = 'Open';
    }
    value(1; "Change Proposed")
    {
        Caption = 'Change Proposed';
    }
    value(2; "Partially Confirmed")
    {
        Caption = 'Partially Confirmed';
    }
    value(3; Confirmed)
    {
        Caption = 'Confirmed';
    }
    value(4; Cancelled)
    {
        Caption = 'Cancelled';
    }
}
