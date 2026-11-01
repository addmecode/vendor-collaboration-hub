namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Identifies whether a collaboration entry was produced by a buyer, vendor or the system.
/// </summary>
enum 50105 "AMC Actor Type"
{
    Extensible = true;

    value(0; Buyer) { Caption = 'Buyer'; }
    value(1; Vendor) { Caption = 'Vendor'; }
    value(2; System) { Caption = 'System'; }
    value(3; Integration) { Caption = 'Integration'; }
}
