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
        }
        field("Source Type"; Rec."Source Type")
        {
        }
        field("Source No."; Rec."Source No.")
        {
        }
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
