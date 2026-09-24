namespace Addmecode.VendorCollaborationHub;

permissionset 50103 "AMC API Integration"
{
    Assignable = true;
    Caption = 'Vendor Collaboration API Integration';

    Permissions =
    tabledata "AMC Collaboration Entry" = i,
    tabledata "AMC Vendor Proposal" = RI,
    tabledata "AMC Vendor Proposal Line" = RI,
    tabledata "AMC Vendor Request" = R,
    tabledata "AMC Vendor Request Line" = R,
    codeunit "AMC Proposal Mgt" = X;
}
