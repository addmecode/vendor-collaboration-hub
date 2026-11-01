namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Accumulates ordered validation errors and renders them for API, telemetry and user-facing output.
/// </summary>
codeunit 50122 "AMC Validation Result"
{
    var
        ErrorCodes: List of [Code[20]];
        RequestLineNos: List of [Integer];
        SequenceNos: List of [Integer];
        ErrorTexts: List of [Text];

    /// <summary>
    /// Appends an error without clearing or deduplicating earlier errors.
    /// </summary>
    /// <param name="ErrorCode">The machine-readable validation code.</param>
    /// <param name="RequestLineNo">The affected request line, or zero for a request-level error.</param>
    /// <param name="SequenceNo">The affected sequence, or zero for a request-level error.</param>
    /// <param name="ErrorText">The human-readable error message.</param>
    procedure AddError(ErrorCode: Code[20]; RequestLineNo: Integer; SequenceNo: Integer; ErrorText: Text)
    begin
        this.ErrorCodes.Add(ErrorCode);
        this.RequestLineNos.Add(RequestLineNo);
        this.SequenceNos.Add(SequenceNo);
        this.ErrorTexts.Add(ErrorText);
    end;

    /// <summary>
    /// Checks whether any validation errors have been accumulated.
    /// </summary>
    /// <returns>True when at least one error exists.</returns>
    procedure HasErrors(): Boolean
    begin
        exit(this.ErrorCodes.Count() > 0);
    end;

    /// <summary>
    /// Counts the accumulated validation errors.
    /// </summary>
    /// <returns>The number of errors, including repeated codes.</returns>
    procedure GetErrorCount(): Integer
    begin
        exit(this.ErrorCodes.Count());
    end;

    /// <summary>
    /// Formats all errors in insertion order with codes and available line coordinates, separated by spaces.
    /// </summary>
    /// <returns>The formatted errors, or empty text when no errors exist.</returns>
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

    /// <summary>
    /// Serializes errors in insertion order with code, requestLineNo, sequenceNo and message properties.
    /// </summary>
    /// <returns>A JSON array, empty when there are no errors.</returns>
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

  /// <summary>
  /// Formats only the first error, including its code and available line coordinates.
  /// </summary>
  /// <returns>The first formatted error, or empty text when no errors exist.</returns>
  procedure AsFirstErrorText(): Text
  begin
    if this.HasErrors() then
      exit(this.FormatError(1));
    exit('');
  end;

  /// <summary>
  /// Joins accumulated error codes in insertion order without deduplication.
  /// </summary>
  /// <returns>A comma-separated code list, or empty text when no errors exist.</returns>
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

    /// <summary>
    /// Formats all messages with available line coordinates, omitting machine-readable error codes.
    /// </summary>
    /// <returns>The space-separated display messages, or empty text when no errors exist.</returns>
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
