namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

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
  tabledata "Purchase Line" = RM,
  codeunit "AMC Cancel Remainder Handler" = X,
  codeunit "AMC Change Date Handler" = X,
  codeunit "AMC Change Qty Handler" = X,
  codeunit "AMC Confirm Handler" = X,
  codeunit "AMC Split Delivery Handler" = X,
  codeunit "AMC Substitute Item Handler" = X,
  codeunit "AMC Unknown Line Handler" = X,
  codeunit "AMC Proposal Mgt" = X,
  codeunit "AMC Proposal Validator" = X,
  codeunit "AMC Request Mgt" = X,
  codeunit "AMC Validation Result" = X;
}
