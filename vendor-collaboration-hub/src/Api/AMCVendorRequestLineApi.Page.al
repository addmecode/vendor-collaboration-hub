namespace Addmecode.VendorCollaborationHub;

page 50121 "AMC Vendor Request Line API"
{
    APIPublisher = 'addmecode';
    APIGroup = 'collaboration';
    APIVersion = 'v1.0';
    Caption = 'Vendor Request Line API';
    DelayedInsert = true;
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'vendorRequestLine';
    EntitySetName = 'vendorRequestLines';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "AMC Vendor Request Line";

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
                field(requestNumber; Rec."Request No.")
                {
                    Editable = false;
                }
                field(lineNumber; Rec."Line No.")
                {
                    Editable = false;
                }
                field(purchaseLineNumber; Rec."Purchase Line No.")
                {
                    Editable = false;
                }
                field(itemNumber; Rec."Item No.")
                {
                    Editable = false;
                }
                field(variantCode; Rec."Variant Code")
                {
                    Editable = false;
                }
                field(description; Rec.Description)
                {
                    Editable = false;
                }
                field(locationCode; Rec."Location Code")
                {
                    Editable = false;
                }
                field(unitOfMeasureCode; Rec."Unit of Measure Code")
                {
                    Editable = false;
                }
                field(requestedQuantity; Rec."Requested Quantity")
                {
                    Editable = false;
                }
                field(requestedDeliveryDate; Rec."Requested Delivery Date")
                {
                    Editable = false;
                }
                field(confirmedQuantity; Rec."Confirmed Quantity")
                {
                    Editable = false;
                }
                field(outstandingQuantity; Rec."Outstanding Quantity")
                {
                    Editable = false;
                }
                field(status; Rec.Status)
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
