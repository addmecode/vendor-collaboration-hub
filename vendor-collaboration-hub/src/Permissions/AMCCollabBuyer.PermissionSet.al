namespace Addmecode.VendorCollaborationHub;

permissionset 50101 "AMC Collab Buyer"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Buyer';

    IncludedPermissionSets = "AMC Collab Read";

    Permissions =
    tabledata "AMC Collaboration Entry" = i,
    tabledata "AMC Vendor Proposal" = RIM,
    tabledata "AMC Vendor Proposal Line" = RIM,
    tabledata "AMC Vendor Request" = RIM,
    tabledata "AMC Vendor Request Line" = RIM,
    codeunit "AMC Proposal Mgt" = X,
    codeunit "AMC Proposal Validator" = X,
    codeunit "AMC Request Mgt" = X,
    codeunit "AMC Validation Result" = X;
}
