namespace Addmecode.VendorCollaborationHub;

using System.Globalization;
using System.Integration;

codeunit 50119 "AMC Vendor Email Builder"
{
  procedure Build(VendorRequest: Record "AMC Vendor Request"; AccessLink: Text; var Subject: Text; var HtmlBody: Text; var PlainTextBody: Text)
  var
    OriginalLanguageId: Integer;
    LastErrorText: Text;
  begin
    OriginalLanguageId := GlobalLanguage();
    if not this.TryBuild(VendorRequest, AccessLink, Subject, HtmlBody, PlainTextBody) then begin
      LastErrorText := GetLastErrorText();
      GlobalLanguage(OriginalLanguageId);
      Error(LastErrorText);
    end;
    GlobalLanguage(OriginalLanguageId);
  end;

  [TryFunction]
  local procedure TryBuild(VendorRequest: Record "AMC Vendor Request"; AccessLink: Text; var Subject: Text; var HtmlBody: Text; var PlainTextBody: Text)
  var
    Language: Codeunit Language;
  begin
    GlobalLanguage(this.GetLanguageId(VendorRequest, Language));
    this.BuildContent(VendorRequest, AccessLink, Subject, HtmlBody, PlainTextBody);
  end;

  local procedure GetLanguageId(VendorRequest: Record "AMC Vendor Request"; Language: Codeunit Language): Integer
  begin
    if VendorRequest."Language Code" = '' then
      exit(Language.GetDefaultApplicationLanguageId());

    exit(Language.GetLanguageId(VendorRequest."Language Code"));
  end;

  local procedure BuildContent(VendorRequest: Record "AMC Vendor Request"; AccessLink: Text; var Subject: Text; var HtmlBody: Text; var PlainTextBody: Text)
  var
    LineCount: Integer;
    LineExcerpt: Text;
    SubjectLbl: Label 'Action requested for purchase order %1', Comment = '%1 = purchase order number';
    IntroLbl: Label 'A vendor collaboration request needs your response.';
    PurchaseOrderLbl: Label 'Purchase order';
    RequestLbl: Label 'Request';
    ResponseDeadlineLbl: Label 'Response deadline';
    LinesLbl: Label 'Lines';
    ItemsLbl: Label 'Items';
    OpenRequestLbl: Label 'Open vendor request';
    InvalidAccessLinkErr: Label 'The vendor access link must be an absolute HTTPS URL.';
    WebRequestHelper: Codeunit "Web Request Helper";
  begin
    if not WebRequestHelper.IsSecureHttpUrl(AccessLink) then
      Error(InvalidAccessLinkErr);

    this.GetLineSummary(VendorRequest."No.", LineCount, LineExcerpt);
    Subject := StrSubstNo(SubjectLbl, VendorRequest."Purchase Order No.");

    HtmlBody := '<p>' + IntroLbl + '</p>' +
      '<table>' +
      this.GetHtmlTableRow(PurchaseOrderLbl, VendorRequest."Purchase Order No.") +
      this.GetHtmlTableRow(RequestLbl, VendorRequest."No.") +
      this.GetHtmlTableRow(ResponseDeadlineLbl, Format(VendorRequest."Response Deadline")) +
      this.GetHtmlTableRow(LinesLbl, Format(LineCount)) +
      this.GetHtmlTableRow(ItemsLbl, LineExcerpt) +
      '</table>' +
      '<p><a href="' + this.HtmlEncode(AccessLink) + '">' + OpenRequestLbl + '</a></p>';

    PlainTextBody := IntroLbl + '\\' +
      PurchaseOrderLbl + ': ' + VendorRequest."Purchase Order No." + '\\' +
      RequestLbl + ': ' + VendorRequest."No." + '\\' +
      ResponseDeadlineLbl + ': ' + Format(VendorRequest."Response Deadline") + '\\' +
      LinesLbl + ': ' + Format(LineCount) + '\\' +
      ItemsLbl + ': ' + LineExcerpt + '\\' +
      OpenRequestLbl + ': ' + AccessLink;
  end;

  local procedure GetLineSummary(RequestNo: Code[20]; var LineCount: Integer; var LineExcerpt: Text)
  var
    VendorRequestLine: Record "AMC Vendor Request Line";
    FirstDescription: Text;
    SecondDescription: Text;
  begin
    VendorRequestLine.SetRange("Request No.", RequestNo);
    VendorRequestLine.SetLoadFields(Description);
    if VendorRequestLine.FindSet() then
      repeat
        LineCount += 1;
        case LineCount of
          1:
            FirstDescription := VendorRequestLine.Description;
          2:
            SecondDescription := VendorRequestLine.Description;
        end;
      until VendorRequestLine.Next() = 0;

    LineExcerpt := FirstDescription;
    if SecondDescription <> '' then
      LineExcerpt += '; ' + SecondDescription;
    if LineCount > 2 then
      LineExcerpt += '...';
  end;

  local procedure GetHtmlTableRow(Caption: Text; Value: Text): Text
  begin
    exit('<tr><th>' + this.HtmlEncode(Caption) + '</th><td>' + this.HtmlEncode(Value) + '</td></tr>');
  end;

  local procedure HtmlEncode(Value: Text): Text
  begin
    Value := Value.Replace('&', '&amp;');
    Value := Value.Replace('<', '&lt;');
    Value := Value.Replace('>', '&gt;');
    Value := Value.Replace('"', '&quot;');
    exit(Value.Replace('''', '&#39;'));
  end;
}
