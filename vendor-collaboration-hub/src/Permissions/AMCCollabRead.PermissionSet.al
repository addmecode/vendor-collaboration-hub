namespace Addmecode.VendorCollaborationHub;

permissionset 50100 "AMC Collab Read"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Read';

    Permissions =
    tabledata "AMC Collaboration Setup" = R,
    page "AMC Collaboration Setup" = X;
}
