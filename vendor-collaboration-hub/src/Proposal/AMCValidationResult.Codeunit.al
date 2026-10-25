namespace Addmecode.VendorCollaborationHub;

codeunit 50122 "AMC Validation Result"
{
    var
        ErrorCodes: List of [Code[20]];
        RequestLineNos: List of [Integer];
        SequenceNos: List of [Integer];
        ErrorTexts: List of [Text];

    procedure AddError(ErrorCode: Code[20]; RequestLineNo: Integer; SequenceNo: Integer; ErrorText: Text)
    begin
        this.ErrorCodes.Add(ErrorCode);
        this.RequestLineNos.Add(RequestLineNo);
        this.SequenceNos.Add(SequenceNo);
        this.ErrorTexts.Add(ErrorText);
    end;

    procedure HasErrors(): Boolean
    begin
        exit(this.ErrorCodes.Count() > 0);
    end;

    procedure GetErrorCount(): Integer
    begin
        exit(this.ErrorCodes.Count());
    end;

    procedure AsErrorText(): Text
    var
        ErrorText: TextBuilder;
        Index: Integer;
    begin
        if not this.HasErrors() then
            exit('');

        for Index := 1 to this.ErrorCodes.Count() do begin
            if ErrorText.Length() > 0 then
                ErrorText.Append(' ');
            ErrorText.Append(this.FormatError(Index));
        end;

        exit(ErrorText.ToText());
    end;

    procedure AsJson(): Text
    var
        ErrorJson: JsonObject;
        ErrorsJson: JsonArray;
        JsonText: Text;
        Index: Integer;
    begin
        for Index := 1 to this.ErrorCodes.Count() do begin
            Clear(ErrorJson);
            ErrorJson.Add('code', this.ErrorCodes.Get(Index));
            ErrorJson.Add('requestLineNo', this.RequestLineNos.Get(Index));
            ErrorJson.Add('sequenceNo', this.SequenceNos.Get(Index));
            ErrorJson.Add('message', this.ErrorTexts.Get(Index));
            ErrorsJson.Add(ErrorJson);
        end;

        ErrorsJson.WriteTo(JsonText);
        exit(JsonText);
    end;

  procedure AsFirstErrorText(): Text
  begin
    if this.HasErrors() then
      exit(this.FormatError(1));
  end;

  procedure GetErrorCodeList(): Text
  var
    ErrorCode: Code[20];
    CodeList: TextBuilder;
  begin
    foreach ErrorCode in this.ErrorCodes do begin
      if CodeList.Length() > 0 then
        CodeList.Append(',');
      CodeList.Append(ErrorCode);
    end;
    exit(CodeList.ToText());
  end;

    procedure AsDisplayText(): Text
    var
        ErrorText: TextBuilder;
        Index: Integer;
    begin
        for Index := 1 to this.ErrorTexts.Count() do begin
            if ErrorText.Length() > 0 then
                ErrorText.Append(' ');
            ErrorText.Append(this.FormatDisplayError(Index));
        end;

        exit(ErrorText.ToText());
    end;

    local procedure FormatError(Index: Integer): Text
    var
        LineErrorFormatLbl: Label '%1 [line %2/%3]: %4', Locked = true, Comment = '%1 = error code, %2 = sequence number, %3 = request line number, %4 = error text';
    begin
        if (this.RequestLineNos.Get(Index) = 0) and (this.SequenceNos.Get(Index) = 0) then
            exit(StrSubstNo('%1: %2', this.ErrorCodes.Get(Index), this.ErrorTexts.Get(Index)));

        exit(StrSubstNo(LineErrorFormatLbl, this.ErrorCodes.Get(Index), this.SequenceNos.Get(Index), this.RequestLineNos.Get(Index), this.ErrorTexts.Get(Index)));
    end;

    local procedure FormatDisplayError(Index: Integer): Text
    var
        LineErrorFormatLbl: Label 'Line %1/%2: %3', Comment = '%1 = sequence number, %2 = request line number, %3 = error text';
    begin
        if (this.RequestLineNos.Get(Index) = 0) and (this.SequenceNos.Get(Index) = 0) then
            exit(this.ErrorTexts.Get(Index));

        exit(StrSubstNo(LineErrorFormatLbl, this.SequenceNos.Get(Index), this.RequestLineNos.Get(Index), this.ErrorTexts.Get(Index)));
    end;
}
