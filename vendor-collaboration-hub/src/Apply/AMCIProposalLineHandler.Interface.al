namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

interface "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line"; var RequestLine: Record "AMC Vendor Request Line"; var Result: Codeunit "AMC Validation Result");

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line"; var PurchaseHeader: Record "Purchase Header");
}
