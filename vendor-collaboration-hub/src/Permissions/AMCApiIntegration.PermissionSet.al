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
    tabledata "AMC Vendor Access Token" = Rm,
    tabledata "Purchase Line" = R,
    codeunit "AMC Change Date Handler" = X,
    codeunit "AMC Change Qty Handler" = X,
    codeunit "AMC Confirm Handler" = X,
    codeunit "AMC Unknown Line Handler" = X,
    codeunit "AMC Proposal Mgt" = X,
    codeunit "AMC Proposal Validator" = X,
    codeunit "AMC Validation Result" = X,
    codeunit "AMC Access Token Mgt" = X,
    codeunit "AMC API Token Scope" = X,
    codeunit "AMC Collab Log" = X,
    table "AMC Vendor Request" = X,
    table "AMC Vendor Request Line" = X,
    table "AMC Vendor Access Token" = X,
    page "AMC Vendor Request API" = X,
    page "AMC Vendor Request Line API" = X,
    page "AMC Vendor Access Token API" = X;
}
