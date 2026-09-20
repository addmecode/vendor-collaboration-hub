namespace Addmecode.VendorCollaborationHub;

using System.Environment.Configuration;
using System.Media;

codeunit 50109 "AMC Install"
{
  Subtype = Install;

  [EventSubscriber(ObjectType::Codeunit, Codeunit::"Guided Experience", 'OnRegisterAssistedSetup', '', false, false)]
  local procedure RegisterAssistedSetup()
  var
    GuidedExperience: Codeunit "Guided Experience";
    AssistedSetupGroup: Enum "Assisted Setup Group";
    GuidedExperienceType: Enum "Guided Experience Type";
    VideoCategory: Enum "Video Category";
  begin
    if GuidedExperience.Exists(GuidedExperienceType::"Assisted Setup", ObjectType::Page, Page::"AMC Assisted Setup") then
      exit;

    GuidedExperience.InsertAssistedSetup(
      this.AssistedSetupTitleLbl,
      this.AssistedSetupShortTitleLbl,
      this.AssistedSetupDescriptionLbl,
      5,
      ObjectType::Page,
      Page::"AMC Assisted Setup",
      AssistedSetupGroup::GettingStarted,
      '',
      VideoCategory::GettingStarted,
      '',
      true);
  end;

  var
    AssistedSetupDescriptionLbl: Label 'Choose the number series used for vendor requests and proposals.';
    AssistedSetupShortTitleLbl: Label 'Vendor Collaboration', MaxLength = 50;
    AssistedSetupTitleLbl: Label 'Set up Vendor Collaboration';
} 
