namespace Addmecode.VendorCollaborationHub;

page 50120 "AMC Vendor Request API"
{
    APIPublisher = 'addmecode';
    APIGroup = 'collaboration';
    APIVersion = 'v1.0';
    Caption = 'Vendor Request API';
    DelayedInsert = true;
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'vendorRequest';
    EntitySetName = 'vendorRequests';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "AMC Vendor Request";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(id; Rec.SystemId)
                {
                    Editable = false;
                }
                field(requestNumber; Rec."No.")
                {
                    Editable = false;
                }
                field(vendorNumber; Rec."Vendor No.")
                {
                    Editable = false;
                }
                field(purchaseOrderNumber; Rec."Purchase Order No.")
                {
                    Editable = false;
                }
                field(status; Rec.Status)
                {
                    Editable = false;
                }
                field(purchaserCode; Rec."Purchaser Code")
                {
                    Editable = false;
                }
                field(assignedUserId; Rec."Assigned User ID")
                {
                    Editable = false;
                }
                field(sentDateTime; Rec."Sent Date Time")
                {
                    Editable = false;
                }
                field(responseDeadline; Rec."Response Deadline")
                {
                    Editable = false;
                }
                field(closedDateTime; Rec."Closed Date Time")
                {
                    Editable = false;
                }
                field(externalReference; Rec."External Reference")
                {
                    Editable = false;
                }
                field(currencyCode; Rec."Currency Code")
                {
                    Editable = false;
                }
                field(languageCode; Rec."Language Code")
                {
                    Editable = false;
                }
                field(openProposalCount; Rec."Open Proposal Count")
                {
                    Editable = false;
                }
                field(lineCount; Rec."Line Count")
                {
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Editable = false;
                }
            }
        }
    }
}
