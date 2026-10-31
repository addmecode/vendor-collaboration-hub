namespace Addmecode.VendorCollaborationHub;

codeunit 50106 "AMC Telemetry"
{
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
