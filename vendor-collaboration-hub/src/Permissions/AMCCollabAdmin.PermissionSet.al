namespace Addmecode.VendorCollaborationHub;

using Microsoft.Foundation.NoSeries;
using System.Threading;

permissionset 50102 "AMC Collab Admin"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Admin', MaxLength = 30;

    IncludedPermissionSets = "AMC Collab Buyer";

    Permissions =
    tabledata "AMC Collaboration Setup" = RIMD,
    tabledata "Job Queue Entry" = RIMD,
    tabledata "No. Series" = R,
    codeunit "AMC Install" = X,
    codeunit "AMC Token Expiry Job" = X,
    page "AMC Assisted Setup" = X,
    page "AMC Collaboration Entries" = X,
    page "No. Series" = X;
}
