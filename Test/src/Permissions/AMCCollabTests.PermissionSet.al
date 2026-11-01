namespace Addmecode.VendorCollaborationHub.Tests;

/// <summary>
/// Grants execute-only access to the test codeunits and their local helpers.
/// Data access and application execution permissions must be assigned separately to the test user.
/// </summary>
permissionset 50130 "AMC Collab Tests"
{
  Assignable = true;
  Caption = 'Vendor Collaboration Tests', MaxLength = 30;

  Permissions =
    codeunit "AMC Access Token API Tests" = X,
    codeunit "AMC Access Token Tests" = X,
    codeunit "AMC Apply Orchestration Tests" = X,
    codeunit "AMC Cancel Remainder Tests" = X,
    codeunit "AMC Change Date Handler Tests" = X,
    codeunit "AMC Change Qty Handler Tests" = X,
    codeunit "AMC Collab Log Tests" = X,
    codeunit "AMC Comment API Tests" = X,
    codeunit "AMC Confirm Handler Tests" = X,
    codeunit "AMC Email Send Test Handler" = X,
    codeunit "AMC Order Lock Tests" = X,
    codeunit "AMC Proposal Tests" = X,
    codeunit "AMC Request Tests" = X,
    codeunit "AMC Setup Tests" = X,
    codeunit "AMC Split Delivery Tests" = X,
    codeunit "AMC Substitute Item Tests" = X,
    codeunit "AMC Test Library" = X,
    codeunit "AMC Vendor Notification Tests" = X,
    codeunit "AMC Write API Tests" = X;
}
