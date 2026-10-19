namespace Addmecode.VendorCollaborationHub;

page 50112 "AMC Collaboration Entries"
{
  ApplicationArea = All;
  Caption = 'Collaboration Entries';
  DeleteAllowed = false;
  Editable = false;
  InsertAllowed = false;
  ModifyAllowed = false;
  PageType = List;
  SourceTable = "AMC Collaboration Entry";
  SourceTableView = sorting("Source Type", "Source No.", "Date Time") order(descending);
  UsageCategory = Lists;

  layout
  {
    area(Content)
    {
      repeater(Entries)
      {
        field("Entry No."; Rec."Entry No.")
        {
          ToolTip = 'Specifies the unique number of this collaboration entry.';
        }
        field("Source Type"; Rec."Source Type")
        {
          ToolTip = 'Specifies whether this entry belongs to a request or a proposal.';
        }
        field("Source No."; Rec."Source No.")
        {
          ToolTip = 'Specifies the request or proposal number for this entry.';
        }
        field("Date Time"; Rec."Date Time")
        {
          ToolTip = 'Specifies when this entry was recorded.';
        }
        field("Entry Type"; Rec."Entry Type")
        {
          ToolTip = 'Specifies the process event or comment recorded by this entry.';
        }
        field("Source Line No."; Rec."Source Line No.")
        {
          ToolTip = 'Specifies the related source line, if any.';
        }
        field("Actor Type"; Rec."Actor Type")
        {
          ToolTip = 'Specifies who performed the action.';
        }
        field("Actor Name"; Rec."Actor Name")
        {
          ToolTip = 'Specifies the actor name recorded for this entry.';
        }
        field("User ID"; Rec."User ID")
        {
          ToolTip = 'Specifies the Business Central user recorded for this entry.';
        }
        field(Description; Rec.Description)
        {
          ToolTip = 'Specifies the comment or context recorded for this entry.';
        }
        field("Field Name"; Rec."Field Name")
        {
          ToolTip = 'Specifies the changed field, if any.';
        }
        field("Old Value"; Rec."Old Value")
        {
          ToolTip = 'Specifies the value before the change, if any.';
        }
        field("New Value"; Rec."New Value")
        {
          ToolTip = 'Specifies the value after the change, if any.';
        }
        field("Correlation Id"; Rec."Correlation Id")
        {
          ToolTip = 'Specifies the identifier that correlates this entry with telemetry.';
        }
      }
    }
  }
}
