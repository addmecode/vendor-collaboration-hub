namespace Addmecode.VendorCollaborationHub;

using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

permissionset 50100 "AMC Collab Read"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Read';

    Permissions =
    tabledata "AMC Collaboration Setup" = R,
    tabledata "AMC Collaboration Entry" = R,
    tabledata "AMC Vendor Proposal" = R,
    tabledata "AMC Vendor Proposal Line" = R,
    tabledata "AMC Vendor Request" = R,
    tabledata "AMC Vendor Request Line" = R,
    tabledata Item = R,
    tabledata "Purchase Header" = R,
    tabledata "Purchase Line" = R,
    tabledata Vendor = R,
    page "AMC Collaboration Setup" = X,
    page "AMC Collab Timeline" = X,
    page "AMC Vendor Proposal" = X,
    page "AMC Vendor Proposal Subform" = X,
    page "AMC Vendor Proposals" = X,
    page "AMC Vendor Request" = X,
    page "AMC Vendor Request Subform" = X,
    page "AMC Vendor Requests" = X;
}
