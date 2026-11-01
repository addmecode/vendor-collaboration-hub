namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Identifies the request or proposal to which a collaboration entry belongs.
/// </summary>
enum 50106 "AMC Source Type"
{
    Extensible = true;

    value(0; Request) { Caption = 'Request'; }
    value(1; Proposal) { Caption = 'Proposal'; }
}
