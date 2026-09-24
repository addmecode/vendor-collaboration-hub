namespace Addmecode.VendorCollaborationHub;

codeunit 50106 "AMC Telemetry"
{
    procedure LogMessage(EventId: Text; Message: Text; MessageVerbosity: Verbosity; var CustomDimensions: Dictionary of [Text, Text])
    begin
        CustomDimensions.Set(this.VCHEventIdLbl, EventId);
        Session.LogMessage(EventId, Message, MessageVerbosity, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    procedure LogRequestCreated(RequestNo: Code[20]; VendorNo: Code[20]; OrderNo: Code[20]; LineCount: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
        RequestCreatedMsg: Label 'Vendor request created.';
    begin
        CustomDimensions.Add(this.VCHRequestNoLbl, RequestNo);
        CustomDimensions.Add(this.VCHVendorNoLbl, VendorNo);
        CustomDimensions.Add(this.VCHOrderNoLbl, OrderNo);
        CustomDimensions.Add(this.VCHLineCountLbl, Format(LineCount));
        this.LogMessage(this.VCH0101Lbl, RequestCreatedMsg, Verbosity::Normal, CustomDimensions);
    end;

    var
        VCH0101Lbl: Label 'VCH0101', Locked = true;
        VCH0102Lbl: Label 'VCH0102', Locked = true;
        VCH0110Lbl: Label 'VCH0110', Locked = true;
        VCH0120Lbl: Label 'VCH0120', Locked = true;
        VCH0121Lbl: Label 'VCH0121', Locked = true;
        VCH0122Lbl: Label 'VCH0122', Locked = true;
        VCH0123Lbl: Label 'VCH0123', Locked = true;
        VCH0124Lbl: Label 'VCH0124', Locked = true;
        VCH0125Lbl: Label 'VCH0125', Locked = true;
        VCH0201Lbl: Label 'VCH0201', Locked = true;
        VCH0202Lbl: Label 'VCH0202', Locked = true;
        VCH0203Lbl: Label 'VCH0203', Locked = true;
        VCH0210Lbl: Label 'VCH0210', Locked = true;
        VCH0220Lbl: Label 'VCH0220', Locked = true;
        VCH0221Lbl: Label 'VCH0221', Locked = true;
        VCH0230Lbl: Label 'VCH0230', Locked = true;
        VCH0240Lbl: Label 'VCH0240', Locked = true;
        VCHEventIdLbl: Label 'vchEventId', Locked = true;
        VCHRequestNoLbl: Label 'vchRequestNo', Locked = true;
        VCHProposalNoLbl: Label 'vchProposalNo', Locked = true;
        VCHVendorNoLbl: Label 'vchVendorNo', Locked = true;
        VCHOrderNoLbl: Label 'vchOrderNo', Locked = true;
        VCHLineCountLbl: Label 'vchLineCount', Locked = true;
        VCHDurationMsLbl: Label 'vchDurationMs', Locked = true;
        VCHResultLbl: Label 'vchResult', Locked = true;
        VCHErrorCodeLbl: Label 'vchErrorCode', Locked = true;
        VCHCorrelationIdLbl: Label 'vchCorrelationId', Locked = true;
        VCHLineTypeLbl: Label 'vchLineType', Locked = true;
        VCHTokenIdLbl: Label 'vchTokenId', Locked = true;
}
