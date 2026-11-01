namespace Addmecode.VendorCollaborationHub;

using Microsoft.CRM.Team;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;
using System.Security.AccessControl;

/// <summary>
/// Stores the purchase-order request snapshot, response deadline and request lifecycle metadata.
/// </summary>
table 50101 "AMC Vendor Request"
{
    Caption = 'Vendor Request';
    DataClassification = CustomerContent;
    DrillDownPageId = "AMC Vendor Requests";
    LookupPageId = "AMC Vendor Requests";
    Permissions = tabledata "AMC Vendor Request" = r;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            ToolTip = 'Specifies the vendor request number.';
            NotBlank = true;
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            ToolTip = 'Specifies the vendor that receives this request.';
            TableRelation = Vendor;
        }
        field(3; "Vendor Name"; Text[100])
        {
            CalcFormula = lookup(Vendor.Name where("No." = field("Vendor No.")));
            Caption = 'Vendor Name';
            ToolTip = 'Specifies the name of the vendor that receives this request.';
            Editable = false;
            FieldClass = FlowField;
        }
        field(4; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
            ToolTip = 'Specifies the purchase order captured by this request.';
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Order));
        }
        field(5; Status; Enum "AMC Request Status")
        {
            Caption = 'Status';
            ToolTip = 'Specifies the current status of the vendor request.';
        }
        field(6; "Purchaser Code"; Code[20])
        {
            Caption = 'Purchaser Code';
            ToolTip = 'Specifies the purchaser responsible for this request.';
            TableRelation = "Salesperson/Purchaser";
        }
        field(7; "Assigned User ID"; Code[50])
        {
            Caption = 'Assigned User ID';
            ToolTip = 'Specifies the user assigned to this request.';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(8; "Sent Date Time"; DateTime)
        {
            Caption = 'Sent Date Time';
            ToolTip = 'Specifies when this request was sent to the vendor.';
        }
        field(9; "Response Deadline"; Date)
        {
            Caption = 'Response Deadline';
            ToolTip = 'Specifies the date by which the vendor should respond.';
        }
        field(10; "Closed Date Time"; DateTime)
        {
            Caption = 'Closed Date Time';
            ToolTip = 'Specifies when this request was closed.';
        }
        field(11; "External Reference"; Text[50])
        {
            Caption = 'External Reference';
            ToolTip = 'Specifies the vendor reference for this request.';
        }
        field(12; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            ToolTip = 'Specifies the currency copied from the purchase order.';
        }
        field(13; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
            ToolTip = 'Specifies the language used when communicating with the vendor.';
        }
        field(14; "Open Proposal Count"; Integer)
        {
            CalcFormula = count("AMC Vendor Proposal" where(
                "Request No." = field("No."),
                Status = filter(Submitted | "In Review")));
            Caption = 'Open Proposal Count';
            ToolTip = 'Specifies the number of proposals awaiting review for this request.';
            Editable = false;
            FieldClass = FlowField;
        }
        field(15; "Line Count"; Integer)
        {
            CalcFormula = count("AMC Vendor Request Line" where("Request No." = field("No.")));
            Caption = 'Line Count';
            ToolTip = 'Specifies the number of lines in this request.';
            Editable = false;
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
        PersistedVendorRequest.SetLoadFields("Vendor No.", "Purchase Order No.", "Purchaser Code", "Assigned User ID", "Currency Code");
        if PersistedVendorRequest.Get(this."No.") and
           ((this."Vendor No." <> PersistedVendorRequest."Vendor No.") or
            (this."Purchase Order No." <> PersistedVendorRequest."Purchase Order No.") or
            (this."Purchaser Code" <> PersistedVendorRequest."Purchaser Code") or
            (this."Assigned User ID" <> PersistedVendorRequest."Assigned User ID") or
            (this."Currency Code" <> PersistedVendorRequest."Currency Code")) then
            Error(RequestSnapshotCannotBeChangedErr);
    end;

  /// <summary>
  /// Initializes the current request buffer to Draft without inserting or persisting it.
  /// </summary>
  procedure InitRecord()
  begin
    Rec.Validate(Status, Rec.Status::Draft);
  end;
}
