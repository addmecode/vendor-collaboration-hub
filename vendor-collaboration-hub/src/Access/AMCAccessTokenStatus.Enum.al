namespace Addmecode.VendorCollaborationHub;

enum 50107 "AMC Access Token Status"
{
    Extensible = true;

    value(0; Active)
    {
        Caption = 'Active';
    }
    value(1; Expired)
    {
        Caption = 'Expired';
    }
    value(2; Revoked)
    {
        Caption = 'Revoked';
    }
    value(3; Superseded)
    {
        Caption = 'Superseded';
    }
}
