namespace Addmecode.VendorCollaborationHub;

permissionset 50101 "AMC Collab Buyer"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Buyer';

    IncludedPermissionSets = "AMC Collab Read";

    Permissions =
    tabledata "AMC Vendor Request" = RIM,
    tabledata "AMC Vendor Request Line" = RIM;
}
