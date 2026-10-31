namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Defines the telemetry verbosity choices available in collaboration setup.
/// </summary>
enum 50108 "AMC Telemetry Verbosity"
{
  Extensible = false;

  value(0; " ")
  {
    Caption = ' ', Locked = true;
  }
  value(1; Normal)
  {
    Caption = 'Normal';
  }
  value(2; Warning)
  {
    Caption = 'Warning';
  }
  value(3; Error)
  {
    Caption = 'Error';
  }
  value(4; Verbose)
  {
    Caption = 'Verbose';
  }
}
