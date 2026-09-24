namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Vendor;

tableextension 50102 "AMC Vendor Ext" extends Vendor
{
    fields
    {
        field(50100; "AMC Collaboration Enabled"; Boolean)
        {
            Caption = 'Collaboration Enabled';
            DataClassification = SystemMetadata;
        }
    }
}
