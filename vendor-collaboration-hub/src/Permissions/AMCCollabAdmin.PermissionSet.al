namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;

permissionset 50102 "AMC Collab Admin"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Admin';

    IncludedPermissionSets = "AMC Collab Buyer";

    Permissions =
    tabledata "AMC Collaboration Setup" = RIMD,
    tabledata "No. Series" = R,
    page "AMC Assisted Setup" = X,
    page "No. Series" = X;
}
