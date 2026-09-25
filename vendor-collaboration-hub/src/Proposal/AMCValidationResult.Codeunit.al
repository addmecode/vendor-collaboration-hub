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
        ErrorText: Text;
        Index: Integer;
    begin
        if not this.HasErrors() then
            exit('');

        for Index := 1 to this.ErrorCodes.Count() do begin
            if ErrorText <> '' then
                ErrorText += ' ';
            ErrorText += this.FormatError(Index);
        end;

        exit(ErrorText);
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

    procedure AsDisplayText(): Text
    var
        ErrorText: Text;
        Index: Integer;
    begin
        for Index := 1 to this.ErrorTexts.Count() do begin
            if ErrorText <> '' then
                ErrorText += ' ';
            ErrorText += this.FormatDisplayError(Index);
        end;

        exit(ErrorText);
    end;

    local procedure FormatError(Index: Integer): Text
    begin
        if this.RequestLineNos.Get(Index) = 0 then
            exit(StrSubstNo('%1: %2', this.ErrorCodes.Get(Index), this.ErrorTexts.Get(Index)));

        exit(StrSubstNo('%1 [line %2/%3]: %4', this.ErrorCodes.Get(Index), this.SequenceNos.Get(Index), this.RequestLineNos.Get(Index), this.ErrorTexts.Get(Index)));
    end;

    local procedure FormatDisplayError(Index: Integer): Text
    begin
        if this.RequestLineNos.Get(Index) = 0 then
            exit(this.ErrorTexts.Get(Index));

        exit(StrSubstNo('Line %1/%2: %3', this.SequenceNos.Get(Index), this.RequestLineNos.Get(Index), this.ErrorTexts.Get(Index)));
    end;
}
