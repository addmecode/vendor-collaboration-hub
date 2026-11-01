namespace Addmecode.VendorCollaborationHub;

page 50107 "AMC Collab Timeline"
{
    ApplicationArea = All;
    Caption = 'Collaboration Timeline';
    DeleteAllowed = false;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = ListPart;
    SourceTable = "AMC Collaboration Entry";
    SourceTableView = sorting("Source Type", "Source No.", "Date Time") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Date Time"; Rec."Date Time")
                {
                }
                field("Entry Type"; Rec."Entry Type")
                {
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                }
                field("Actor Type"; Rec."Actor Type")
                {
                }
                field("Actor Name"; Rec."Actor Name")
                {
                }
                field("User ID"; Rec."User ID")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Field Name"; Rec."Field Name")
                {
                }
                field("Old Value"; Rec."Old Value")
                {
                }
                field("New Value"; Rec."New Value")
                {
                }
                field("Correlation Id"; Rec."Correlation Id")
                {
                }
            }
        }
    }
}
