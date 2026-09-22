namespace Addmecode.VendorCollaborationHub;

table 50103 "AMC Vendor Proposal"
{
    Caption = 'Vendor Proposal';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
        }
        field(2; "Request No."; Code[20])
        {
            Caption = 'Request No.';
            DataClassification = CustomerContent;
            TableRelation = "AMC Vendor Request";
        }
        field(5; Status; Enum "AMC Proposal Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(RequestStatus; "Request No.", Status)
        {
        }
    }
}
