namespace Addmecode.VendorCollaborationHub;

using Microsoft.Purchases.Document;

tableextension 50101 "AMC Purchase Line Ext" extends "Purchase Line"
{
  fields
  {
    field(50100; "AMC Origin Proposal No."; Code[20])
    {
      Caption = 'Origin Proposal No.';
      DataClassification = CustomerContent;
    }
    field(50101; "AMC Origin Proposal Line No."; Integer)
    {
      Caption = 'Origin Proposal Line No.';
      DataClassification = CustomerContent;
    }
    field(50102; "AMC Vendor Confirmed"; Boolean)
    {
      Caption = 'Vendor Confirmed';
      DataClassification = CustomerContent;
    }
  }
}
