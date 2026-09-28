namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using System.Threading;

permissionset 50102 "AMC Collab Admin"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Admin';

    IncludedPermissionSets = "AMC Collab Buyer";

    Permissions =
    tabledata "AMC Collaboration Setup" = RIMD,
    tabledata "Job Queue Entry" = RIMD,
    tabledata "No. Series" = R,
    page "AMC Assisted Setup" = X,
    page "No. Series" = X,
    codeunit "AMC Token Expiry Job" = X;
}
