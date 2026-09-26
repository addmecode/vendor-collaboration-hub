namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

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
  tabledata "Purchase Line" = R,
  codeunit "AMC Change Date Handler" = X,
  codeunit "AMC Change Qty Handler" = X,
  codeunit "AMC Confirm Handler" = X,
  codeunit "AMC Unknown Line Handler" = X,
  codeunit "AMC Proposal Mgt" = X,
  codeunit "AMC Proposal Validator" = X,
  codeunit "AMC Validation Result" = X;
}
