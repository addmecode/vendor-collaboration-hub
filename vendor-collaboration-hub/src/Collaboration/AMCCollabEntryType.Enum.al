namespace Addmecode.VendorCollaborationHub;

enum 50104 "AMC Collab Entry Type"
{
    Extensible = true;

    value(0; Comment) { Caption = 'Comment'; }
    value(1; RequestCreated) { Caption = 'Request Created'; }
    value(2; RequestSent) { Caption = 'Request Sent'; }
    value(3; RequestCancelled) { Caption = 'Request Cancelled'; }
    value(4; LinkIssued) { Caption = 'Link Issued'; }
    value(5; LinkSent) { Caption = 'Link Sent'; }
    value(6; LinkSendFailed) { Caption = 'Link Send Failed'; }
    value(7; LinkOpened) { Caption = 'Link Opened'; }
    value(8; LinkRejected) { Caption = 'Link Rejected'; }
    value(9; LinkRevoked) { Caption = 'Link Revoked'; }
    value(10; ProposalReceived) { Caption = 'Proposal Received'; }
    value(11; ProposalValidationFailed) { Caption = 'Proposal Validation Failed'; }
    value(12; ProposalSubmitted) { Caption = 'Proposal Submitted'; }
    value(13; ChangesRequested) { Caption = 'Changes Requested'; }
    value(14; ProposalApproved) { Caption = 'Proposal Approved'; }
    value(15; ProposalRejected) { Caption = 'Proposal Rejected'; }
    value(16; ProposalApplied) { Caption = 'Proposal Applied'; }
    value(17; PriceRecalculated) { Caption = 'Price Recalculated'; }
    value(18; ProposalApplyFailed) { Caption = 'Proposal Apply Failed'; }
    value(19; OrderUnlocked) { Caption = 'Order Unlocked'; }
    value(20; ProposalSuperseded) { Caption = 'Proposal Superseded'; }
}
