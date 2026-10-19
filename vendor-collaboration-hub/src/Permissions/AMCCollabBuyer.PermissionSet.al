namespace Addmecode.VendorCollaborationHub;

using Microsoft.CRM.Team;
using Microsoft.Purchases.Document;
using System.Email;

permissionset 50101 "AMC Collab Buyer"
{
    Assignable = true;
    Caption = 'Vendor Collaboration Buyer', MaxLength = 30;

    IncludedPermissionSets = "AMC Collab Read",
                           "Email - Edit";

    Permissions =
    tabledata "AMC Collaboration Entry" = i,
    tabledata "AMC Vendor Access Token" = RIM,
    tabledata "AMC Vendor Proposal" = RIM,
    tabledata "AMC Vendor Proposal Line" = RIM,
    tabledata "AMC Vendor Request" = RIM,
    tabledata "AMC Vendor Request Line" = RIM,
    tabledata "Purchase Line" = RM,
    tabledata "Salesperson/Purchaser" = R,
    codeunit "AMC Access Token Mgt" = X,
    codeunit "AMC Apply Proposal Svc" = X,
    codeunit "AMC Cancel Remainder Handler" = X,
    codeunit "AMC Change Date Handler" = X,
    codeunit "AMC Change Qty Handler" = X,
    codeunit "AMC Collab Log" = X,
    codeunit "AMC Confirm Handler" = X,
    codeunit "AMC Order Lock Mgt" = X,
    codeunit "AMC Proposal Decision Svc" = X,
    codeunit "AMC Proposal Mgt" = X,
    codeunit "AMC Proposal Validator" = X,
    codeunit "AMC Purchase Events" = X,
    codeunit "AMC Purchase Line Builder" = X,
    codeunit "AMC Request Mgt" = X,
    codeunit "AMC Split Delivery Handler" = X,
    codeunit "AMC Substitute Item Handler" = X,
    codeunit "AMC Telemetry" = X,
    codeunit "AMC Unknown Line Handler" = X,
    codeunit "AMC Validation Result" = X,
    codeunit "AMC Vendor Email Builder" = X,
    codeunit "AMC Vendor Notification" = X,
    codeunit "Release Purchase Document" = X,
    page "AMC Vendor Access Links" = X,
    page "AMC Vendor Access Links Part" = X,
    report Order = X;
}
