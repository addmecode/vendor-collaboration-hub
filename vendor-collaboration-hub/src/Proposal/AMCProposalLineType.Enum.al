namespace Addmecode.VendorCollaborationHub;

enum 50103 "AMC Proposal Line Type" implements "AMC IProposalLineHandler"
{
  Extensible = true;
  UnknownValueImplementation = "AMC IProposalLineHandler" = "AMC Unknown Line Handler";

  value(0; Confirm)
  {
    Caption = 'Confirm';
    Implementation = "AMC IProposalLineHandler" = "AMC Confirm Handler";
  }
  value(1; "Change Quantity")
  {
    Caption = 'Change Quantity';
    Implementation = "AMC IProposalLineHandler" = "AMC Change Qty Handler";
  }
  value(2; "Change Date")
  {
    Caption = 'Change Date';
    Implementation = "AMC IProposalLineHandler" = "AMC Change Date Handler";
  }
  value(3; "Split Delivery")
  {
    Caption = 'Split Delivery';
    Implementation = "AMC IProposalLineHandler" = "AMC Split Delivery Handler";
  }
  value(4; "Substitute Item")
  {
    Caption = 'Substitute Item';
    Implementation = "AMC IProposalLineHandler" = "AMC Substitute Item Handler";
  }
  value(5; "Cancel Remainder")
  {
    Caption = 'Cancel Remainder';
    Implementation = "AMC IProposalLineHandler" = "AMC Cancel Remainder Handler";
  }
}
