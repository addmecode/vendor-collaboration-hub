namespace Addmecode.VendorCollaborationHub;

enum 50102 "AMC Proposal Status"
{
    Extensible = true;

    value(0; Draft)
    {
        Caption = 'Draft';
    }
    value(1; Submitted)
    {
        Caption = 'Submitted';
    }
    value(2; "In Review")
    {
        Caption = 'In Review';
    }
    value(3; "Changes Requested")
    {
        Caption = 'Changes Requested';
    }
    value(4; Approved)
    {
        Caption = 'Approved';
    }
    value(5; Rejected)
    {
        Caption = 'Rejected';
    }
    value(6; Applied)
    {
        Caption = 'Applied';
    }
    value(7; "Apply Failed")
    {
        Caption = 'Apply Failed';
    }
    value(8; Withdrawn)
    {
        Caption = 'Withdrawn';
    }
    value(9; Superseded)
    {
        Caption = 'Superseded';
    }
    value(10; Expired)
    {
        Caption = 'Expired';
    }
}
