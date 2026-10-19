namespace Addmecode.VendorCollaborationHub;

using System.Integration;

codeunit 50108 "AMC Business Events"
{
  [ExternalBusinessEvent('VendorProposalSubmitted', 'Vendor proposal submitted', 'Raised when a vendor submits a proposal for a purchase order.', EventCategory::"Vendor Collaboration", '1.0')]
  procedure VendorProposalSubmitted(ProposalNo: Code[20]; VendorNo: Code[20]; PurchaseOrderNo: Code[20]; RequestNo: Code[20])
  begin
  end;
}
