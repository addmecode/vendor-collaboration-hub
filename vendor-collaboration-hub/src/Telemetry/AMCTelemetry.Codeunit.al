namespace Addmecode.VendorCollaborationHub;

/// <summary>
/// Emits collaboration lifecycle telemetry with logical event identifiers and structured dimensions.
/// </summary>
codeunit 50106 "AMC Telemetry"
{
    /// <summary>
    /// Adds the logical event-id dimension and emits pseudonymous telemetry, using All scope for link-send and apply failures.
    /// </summary>
    /// <param name="EventId">The logical collaboration event identifier.</param>
    /// <param name="Message">The telemetry message; callers must exclude bearer tokens and secrets.</param>
    /// <param name="MessageVerbosity">The emitted telemetry severity.</param>
    /// <param name="CustomDimensions">The supplied dimensions, updated with vchEventId before emission.</param>
    procedure LogMessage(EventId: Text; Message: Text; MessageVerbosity: Verbosity; var CustomDimensions: Dictionary of [Text, Text])
    var
        Scope: TelemetryScope;
    begin
        CustomDimensions.Set(this.VCHEventIdTok, EventId);
        Scope := TelemetryScope::ExtensionPublisher;
        if (EventId = this.VCH0122Tok) or (EventId = this.VCH0221Tok) then
            Scope := TelemetryScope::All;
        Session.LogMessage(EventId, Message, MessageVerbosity, DataClassification::EndUserPseudonymousIdentifiers, Scope, CustomDimensions);
    end;

    /// <summary>
    /// Emits the request-created event with request, vendor, order and line-count dimensions.
    /// </summary>
    /// <param name="RequestNo">The created request number.</param>
    /// <param name="VendorNo">The request vendor number.</param>
    /// <param name="OrderNo">The source purchase order number.</param>
    /// <param name="LineCount">The number of snapshotted request lines.</param>
    procedure LogRequestCreated(RequestNo: Code[20]; VendorNo: Code[20]; OrderNo: Code[20]; LineCount: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
        RequestCreatedMsg: Label 'Vendor request created.';
    begin
        CustomDimensions.Add(this.VCHRequestNoTok, RequestNo);
        CustomDimensions.Add(this.VCHVendorNoTok, VendorNo);
        CustomDimensions.Add(this.VCHOrderNoTok, OrderNo);
        CustomDimensions.Add(this.VCHLineCountTok, Format(LineCount));
        this.LogMessage(this.VCH0101Tok, RequestCreatedMsg, Verbosity::Normal, CustomDimensions);
    end;

    /// <summary>
    /// Emits successful proposal-application telemetry with line count and elapsed milliseconds.
    /// </summary>
    /// <param name="ProposalNo">The applied proposal number.</param>
    /// <param name="RequestNo">The related request number.</param>
    /// <param name="OrderNo">The updated purchase order number.</param>
    /// <param name="LineCount">The number of proposal lines.</param>
    /// <param name="Duration">The elapsed application duration.</param>
    procedure LogProposalApplied(ProposalNo: Code[20]; RequestNo: Code[20]; OrderNo: Code[20]; LineCount: Integer; Duration: Duration)
    var
        CustomDimensions: Dictionary of [Text, Text];
        ProposalAppliedMsg: Label 'Vendor proposal applied.';
    begin
        CustomDimensions.Add(this.VCHProposalNoTok, ProposalNo);
        CustomDimensions.Add(this.VCHRequestNoTok, RequestNo);
        CustomDimensions.Add(this.VCHOrderNoTok, OrderNo);
        CustomDimensions.Add(this.VCHLineCountTok, Format(LineCount));
        CustomDimensions.Add(this.VCHDurationMsTok, this.FormatDurationInMilliseconds(Duration));
        CustomDimensions.Add(this.VCHResultTok, 'applied');
        this.LogMessage(this.VCH0220Tok, ProposalAppliedMsg, Verbosity::Normal, CustomDimensions);
    end;

  /// <summary>
  /// Emits the received and submitted events with proposal identity, correlation and line-count dimensions.
  /// </summary>
  /// <param name="VendorProposal">The submitted proposal supplying event identity.</param>
  /// <param name="LineCount">The number of submitted proposal lines.</param>
  procedure LogProposalSubmitted(VendorProposal: Record "AMC Vendor Proposal"; LineCount: Integer)
  var
    CustomDimensions: Dictionary of [Text, Text];
    ReceivedMsg: Label 'Vendor proposal received.';
    SubmittedMsg: Label 'Vendor proposal submitted.';
  begin
    this.AddProposalDimensions(VendorProposal, CustomDimensions);
    CustomDimensions.Add(this.VCHLineCountTok, Format(LineCount, 0, 9));
    CustomDimensions.Add(this.VCHResultTok, 'received');
    this.LogMessage(this.VCH0201Tok, ReceivedMsg, Verbosity::Normal, CustomDimensions);
    CustomDimensions.Set(this.VCHResultTok, 'submitted');
    this.LogMessage(this.VCH0203Tok, SubmittedMsg, Verbosity::Normal, CustomDimensions);
  end;

  /// <summary>
  /// Emits validation-failure telemetry with error count and codes, excluding free-text validation messages.
  /// </summary>
  /// <param name="VendorProposal">The rejected proposal supplying identity and correlation dimensions.</param>
  /// <param name="Result">The accumulated errors to summarize; unchanged.</param>
  procedure LogProposalValidationFailed(VendorProposal: Record "AMC Vendor Proposal"; var Result: Codeunit "AMC Validation Result")
  var
    CustomDimensions: Dictionary of [Text, Text];
    ValidationFailedMsg: Label 'Vendor proposal validation failed.';
    ErrorCountLbl: Label 'vchErrorCount', Locked = true;
    ErrorCodesLbl: Label 'vchErrorCodes', Locked = true;
  begin
    this.AddProposalDimensions(VendorProposal, CustomDimensions);
    CustomDimensions.Add(ErrorCountLbl, Format(Result.GetErrorCount(), 0, 9));
    CustomDimensions.Add(ErrorCodesLbl, Result.GetErrorCodeList());
    CustomDimensions.Add(this.VCHResultTok, 'rejected');
    this.LogMessage(this.VCH0202Tok, ValidationFailedMsg, Verbosity::Error, CustomDimensions);
  end;

  local procedure AddProposalDimensions(VendorProposal: Record "AMC Vendor Proposal"; var CustomDimensions: Dictionary of [Text, Text])
  begin
    CustomDimensions.Add(this.VCHProposalNoTok, VendorProposal."No.");
    CustomDimensions.Add(this.VCHRequestNoTok, VendorProposal."Request No.");
    CustomDimensions.Add(this.VCHVendorNoTok, VendorProposal."Vendor No.");
    CustomDimensions.Add(this.VCHOrderNoTok, VendorProposal."Purchase Order No.");
    CustomDimensions.Add(this.VCHCorrelationIdTok, Format(VendorProposal."Correlation Id", 0, 4));
  end;

    /// <summary>
    /// Emits application-failure telemetry with the error code and elapsed milliseconds, excluding free-text error details.
    /// </summary>
    /// <param name="ProposalNo">The proposal whose application failed.</param>
    /// <param name="RequestNo">The related request number.</param>
    /// <param name="OrderNo">The target purchase order number.</param>
    /// <param name="ErrorCode">The captured application error code.</param>
    /// <param name="Duration">The elapsed application duration.</param>
    procedure LogProposalApplyFailed(ProposalNo: Code[20]; RequestNo: Code[20]; OrderNo: Code[20]; ErrorCode: Code[20]; Duration: Duration)
    var
        CustomDimensions: Dictionary of [Text, Text];
        ProposalApplyFailedMsg: Label 'Vendor proposal apply failed.';
    begin
        CustomDimensions.Add(this.VCHProposalNoTok, ProposalNo);
        CustomDimensions.Add(this.VCHRequestNoTok, RequestNo);
        CustomDimensions.Add(this.VCHOrderNoTok, OrderNo);
        CustomDimensions.Add(this.VCHErrorCodeTok, ErrorCode);
        CustomDimensions.Add(this.VCHDurationMsTok, this.FormatDurationInMilliseconds(Duration));
        CustomDimensions.Add(this.VCHResultTok, 'failed');
        this.LogMessage(this.VCH0221Tok, ProposalApplyFailedMsg, Verbosity::Error, CustomDimensions);
    end;

    /// <summary>
    /// Emits successful link-email handoff telemetry without link or message content.
    /// </summary>
    /// <param name="RequestNo">The notified request number.</param>
    /// <param name="VendorNo">The notified vendor number.</param>
    /// <param name="OrderNo">The related purchase order number.</param>
    procedure LogLinkSent(RequestNo: Code[20]; VendorNo: Code[20]; OrderNo: Code[20])
    var
        CustomDimensions: Dictionary of [Text, Text];
        LinkSentMsg: Label 'Vendor access link email sent.';
    begin
        CustomDimensions.Add(this.VCHRequestNoTok, RequestNo);
        CustomDimensions.Add(this.VCHVendorNoTok, VendorNo);
        CustomDimensions.Add(this.VCHOrderNoTok, OrderNo);
        CustomDimensions.Add(this.VCHResultTok, 'sent');
        this.LogMessage(this.VCH0121Tok, LinkSentMsg, Verbosity::Normal, CustomDimensions);
    end;

    /// <summary>
    /// Emits failed link-email handoff telemetry without bearer link, recipient or message content.
    /// </summary>
    /// <param name="RequestNo">The request whose notification failed.</param>
    /// <param name="VendorNo">The intended vendor number.</param>
    /// <param name="OrderNo">The related purchase order number.</param>
    procedure LogLinkSendFailed(RequestNo: Code[20]; VendorNo: Code[20]; OrderNo: Code[20])
    var
        CustomDimensions: Dictionary of [Text, Text];
        LinkSendFailedMsg: Label 'Vendor access link email failed to send.';
    begin
        CustomDimensions.Add(this.VCHRequestNoTok, RequestNo);
        CustomDimensions.Add(this.VCHVendorNoTok, VendorNo);
        CustomDimensions.Add(this.VCHOrderNoTok, OrderNo);
        CustomDimensions.Add(this.VCHResultTok, 'failed');
        this.LogMessage(this.VCH0122Tok, LinkSendFailedMsg, Verbosity::Error, CustomDimensions);
    end;

    local procedure FormatDurationInMilliseconds(Duration: Duration): Text
    begin
        exit(Format(Duration / 1, 0, 9));
    end;

    var
        VCH0101Tok: Label 'VCH0101', Locked = true;
        VCH0121Tok: Label 'VCH0121', Locked = true;
        VCH0122Tok: Label 'VCH0122', Locked = true;
        VCH0201Tok: Label 'VCH0201', Locked = true;
        VCH0202Tok: Label 'VCH0202', Locked = true;
        VCH0203Tok: Label 'VCH0203', Locked = true;
        VCH0220Tok: Label 'VCH0220', Locked = true;
        VCH0221Tok: Label 'VCH0221', Locked = true;
        VCHEventIdTok: Label 'vchEventId', Locked = true;
        VCHRequestNoTok: Label 'vchRequestNo', Locked = true;
        VCHProposalNoTok: Label 'vchProposalNo', Locked = true;
        VCHVendorNoTok: Label 'vchVendorNo', Locked = true;
        VCHOrderNoTok: Label 'vchOrderNo', Locked = true;
        VCHLineCountTok: Label 'vchLineCount', Locked = true;
        VCHDurationMsTok: Label 'vchDurationMs', Locked = true;
        VCHResultTok: Label 'vchResult', Locked = true;
        VCHErrorCodeTok: Label 'vchErrorCode', Locked = true;
        VCHCorrelationIdTok: Label 'vchCorrelationId', Locked = true;
}
