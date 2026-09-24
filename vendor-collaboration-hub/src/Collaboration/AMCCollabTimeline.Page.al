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
    SourceTableView = sorting("Source Type", "Source No.", "Date Time") order(ascending);

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Date Time"; Rec."Date Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this entry was recorded.';
                }
                field("Entry Type"; Rec."Entry Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the process event or comment recorded by this entry.';
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the related source line, if any.';
                }
                field("Actor Type"; Rec."Actor Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who performed the action.';
                }
                field("Actor Name"; Rec."Actor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the actor name recorded for this entry.';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central user recorded for this entry.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the comment or context recorded for this entry.';
                }
                field("Field Name"; Rec."Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the changed field, if any.';
                }
                field("Old Value"; Rec."Old Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value before the change, if any.';
                }
                field("New Value"; Rec."New Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value after the change, if any.';
                }
                field("Visible to Vendor"; Rec."Visible to Vendor")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this entry can be returned to the vendor.';
                }
                field("Correlation Id"; Rec."Correlation Id")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the identifier that correlates this entry with telemetry.';
                }
            }
        }
    }
}
