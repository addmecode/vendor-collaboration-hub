namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

/// <summary>
/// Defines type-specific proposal-line validation and application, complementing shared proposal validation.
/// </summary>
interface "AMC IProposalLineHandler"
{
  /// <summary>
  /// Performs type-specific checks in addition to shared proposal validation and appends errors to the supplied result.
  /// </summary>
  /// <param name="ProposalLine">The proposed operation to validate.</param>
  /// <param name="RequestLine">The corresponding request-line snapshot.</param>
  /// <param name="Result">The existing result to which validation errors are appended.</param>
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result");

  /// <summary>
  /// Applies one type-specific operation in the caller's transaction after shared validation and order-lock checks.
  /// </summary>
  /// <param name="ProposalLine">The proposal line describing the operation.</param>
  /// <param name="PurchaseHeader">The target purchase order under the caller's application context.</param>
  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header");
}
