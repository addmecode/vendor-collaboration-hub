namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Foundation.AuditCodes;
using Microsoft.Foundation.NoSeries;

permissionset 50103 "AMC API Integration"
{
  Assignable = true;
  Caption = 'Vendor Collaboration API', MaxLength = 30;

  Permissions =
    table "AMC Collaboration Entry" = X,
    tabledata "AMC Collaboration Entry" = ri,
    table "AMC Collaboration Setup" = X,
    tabledata "AMC Collaboration Setup" = r,
    table "AMC Vendor Access Token" = X,
    tabledata "AMC Vendor Access Token" = Rm,
    table "AMC Vendor Proposal" = X,
    tabledata "AMC Vendor Proposal" = RIm,
    table "AMC Vendor Proposal Line" = X,
    tabledata "AMC Vendor Proposal Line" = RI,
    table "AMC Vendor Request" = X,
    tabledata "AMC Vendor Request" = Rm,
    table "AMC Vendor Request Line" = X,
    tabledata "AMC Vendor Request Line" = R,
    tabledata Item = R,
    tabledata "Item Substitution" = R,
    tabledata "No. Series" = R,
    tabledata "No. Series Line" = Rm,
    tabledata "Purchase Header" = R,
    tabledata "Purchase Line" = R,
    tabledata "Reason Code" = R,
    tabledata Vendor = R,
    codeunit "AMC Access Token Mgt" = X,
    codeunit "AMC API Token Scope" = X,
    codeunit "AMC Business Events" = X,
    codeunit "AMC Cancel Remainder Handler" = X,
    codeunit "AMC Change Date Handler" = X,
    codeunit "AMC Change Qty Handler" = X,
    codeunit "AMC Collab Log" = X,
    codeunit "AMC Confirm Handler" = X,
    codeunit "AMC Idempotency Mgt" = X,
    codeunit "AMC Proposal Mgt" = X,
    codeunit "AMC Proposal Validator" = X,
    codeunit "AMC Request Mgt" = X,
    codeunit "AMC Split Delivery Handler" = X,
    codeunit "AMC Substitute Item Handler" = X,
    codeunit "AMC Telemetry" = X,
    codeunit "AMC Unknown Line Handler" = X,
    codeunit "AMC Validation Result" = X,
    codeunit "No. Series" = X,
    page "AMC Collaboration Comment API" = X,
    page "AMC Vendor Access Token API" = X,
    page "AMC Vendor Proposal API" = X,
    page "AMC Vendor Proposal Line API" = X,
    page "AMC Vendor Request API" = X,
    page "AMC Vendor Request Line API" = X;
}
