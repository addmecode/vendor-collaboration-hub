namespace Addmecode.VendorCollaborationHub;

using Microsoft.CRM.Team;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Security.AccessControl;

table 50101 "AMC Vendor Request"
{
    Caption = 'Vendor Request';
    DataClassification = CustomerContent;
    DrillDownPageId = "AMC Vendor Requests";
    LookupPageId = "AMC Vendor Requests";
    Permissions = tabledata "AMC Vendor Request Line" = rd;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            DataClassification = CustomerContent;
            TableRelation = Vendor;
        }
        field(3; "Vendor Name"; Text[100])
        {
            CalcFormula = lookup(Vendor.Name where("No." = field("Vendor No.")));
            Caption = 'Vendor Name';
            FieldClass = FlowField;
        }
        field(4; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
            DataClassification = CustomerContent;
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Order));
        }
        field(5; Status; Enum "AMC Request Status")
        {
            Caption = 'Status';
            DataClassification = CustomerContent;
        }
        field(6; "Purchaser Code"; Code[20])
        {
            Caption = 'Purchaser Code';
            DataClassification = CustomerContent;
            TableRelation = "Salesperson/Purchaser";
        }
        field(7; "Assigned User ID"; Code[50])
        {
            Caption = 'Assigned User ID';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(8; "Sent Date Time"; DateTime)
        {
            Caption = 'Sent Date Time';
            DataClassification = CustomerContent;
        }
        field(9; "Response Deadline"; Date)
        {
            Caption = 'Response Deadline';
            DataClassification = CustomerContent;
        }
        field(10; "Closed Date Time"; DateTime)
        {
            Caption = 'Closed Date Time';
            DataClassification = CustomerContent;
        }
        field(11; "External Reference"; Text[50])
        {
            Caption = 'External Reference';
            DataClassification = CustomerContent;
        }
        field(12; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
        }
        field(13; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
            DataClassification = CustomerContent;
        }
        field(14; "Open Proposal Count"; Integer)
        {
            CalcFormula = count("AMC Vendor Proposal" where(
                "Request No." = field("No."),
                Status = filter(Submitted | "In Review")));
            Caption = 'Open Proposal Count';
            FieldClass = FlowField;
        }
        field(15; "Line Count"; Integer)
        {
            CalcFormula = count("AMC Vendor Request Line" where("Request No." = field("No.")));
            Caption = 'Line Count';
            FieldClass = FlowField;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(VendorStatus; "Vendor No.", Status)
        {
        }
        key(PurchaseOrderStatus; "Purchase Order No.", Status)
        {
        }
        key(StatusResponseDeadline; Status, "Response Deadline")
        {
        }
    }

    trigger OnDelete()
    var
        VendorRequestCannotBeDeletedErr: Label 'Vendor requests cannot be deleted. Cancel the request instead.';
    begin
        Error(VendorRequestCannotBeDeletedErr);
    end;

    trigger OnModify()
    var
        PersistedVendorRequest: Record "AMC Vendor Request";
        RequestSnapshotCannotBeChangedErr: Label 'Vendor request snapshot fields cannot be changed.';
    begin
        //todo: is this check needed?
        if PersistedVendorRequest.Get(this."No.") and
           ((this."Vendor No." <> PersistedVendorRequest."Vendor No.") or
            (this."Purchase Order No." <> PersistedVendorRequest."Purchase Order No.") or
            (this."Purchaser Code" <> PersistedVendorRequest."Purchaser Code") or
            (this."Assigned User ID" <> PersistedVendorRequest."Assigned User ID") or
            (this."Currency Code" <> PersistedVendorRequest."Currency Code")) then
            Error(RequestSnapshotCannotBeChangedErr);
    end;
}
