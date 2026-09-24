namespace Addmecode.VendorCollaborationHub;

enum 50100 "AMC Request Status"
{
    Extensible = true;

    value(0; Draft)
    {
        Caption = 'Draft';
    }
    value(1; Sent)
    {
        Caption = 'Sent';
    }
    value(2; "Awaiting Vendor")
    {
        Caption = 'Awaiting Vendor';
    }
    value(3; "Vendor Responded")
    {
        Caption = 'Vendor Responded';
    }
    value(4; "In Review")
    {
        Caption = 'In Review';
    }
    value(5; Closed)
    {
        Caption = 'Closed';
    }
    value(6; Cancelled)
    {
        Caption = 'Cancelled';
    }
}
