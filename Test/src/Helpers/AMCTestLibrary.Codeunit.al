namespace Addmecode.VendorCollaborationHub.Tests;

using Addmecode.VendorCollaborationHub;
using Microsoft.CRM.Team;
using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.AuditCodes;
using Microsoft.Foundation.NoSeries;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Substitution;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Setup;
using Microsoft.Purchases.Vendor;
using System.Security.User;
using System.TestLibraries.Utilities;

codeunit 50149 "AMC Test Library"
{
  procedure CreateWriteContext(var VendorRequest: Record "AMC Vendor Request"; var AccessToken: Record "AMC Vendor Access Token")
  var
    Vendor: Record Vendor;
    Setup: Record "AMC Collaboration Setup";
    NoSeries: Record "No. Series";
    NoSeriesLine: Record "No. Series Line";
    PurchaseHeader: Record "Purchase Header";
    AccessTokenMgt: Codeunit "AMC Access Token Mgt";
  begin
    // These pure API fixtures do not send email, apply purchasing changes or use HTTP.
    this.PrepareManualNumbering();
    Vendor.Init();
    Vendor.Validate("No.", this.NewCode());
    Vendor.Validate("AMC Collaboration Enabled", true);
    Vendor.Insert(false);
    NoSeries.Init();
    NoSeries.Validate(Code, this.NewCode());
    NoSeries.Validate("Default Nos.", true);
    NoSeries.Insert(false);
    NoSeriesLine.Init();
    NoSeriesLine.Validate("Series Code", NoSeries.Code);
    NoSeriesLine.Validate("Line No.", 10000);
    NoSeriesLine.Validate("Starting No.", CopyStr(NoSeries.Code, 1, 10) + '-000001');
    NoSeriesLine.Validate("Increment-by No.", 1);
    NoSeriesLine.Insert(false);
    if not Setup.Get() then begin
      Setup.Init();
      Setup.Insert(false);
    end;
    Setup.Validate(Enabled, false);
    Setup.Validate("Request Nos.", NoSeries.Code);
    Setup.Validate("Proposal Nos.", NoSeries.Code);
    Setup.Validate("Portal Base URL", 'https://portal.contoso.com');
    Setup.Validate("Portal Support E-Mail", 'support@contoso.com');
    Setup.Validate("Default Response Days", 7);
    Setup.Validate("Link Validity Days", 14);
    Setup.Validate("Allow Item Substitution", true);
    Setup.Validate("Max Splits per Line", 2);
    Setup.Validate("Require Reason Code", true);
    Setup.Validate(Enabled, true);
    Setup.Modify(false);
    this.CreatePurchaseOrder(PurchaseHeader, this.NewCode(), Vendor."No.");
    VendorRequest.Init();
    VendorRequest.Validate("No.", this.NewCode());
    VendorRequest.Validate("Vendor No.", Vendor."No.");
    VendorRequest.Validate("Purchase Order No.", PurchaseHeader."No.");
    VendorRequest.Validate(Status, VendorRequest.Status::"Awaiting Vendor");
    VendorRequest.Insert(false);
    this.CreateRequestLine(VendorRequest."No.", 10000, 'ITEM-A', 1000);
    this.CreateRequestLine(VendorRequest."No.", 20000, 'ITEM-B', 500);
    this.EnsureReason('CAPACITY');
    this.EnsureReason('UNAVAIL');
    this.EnsureSubstitution();
    AccessToken.Init();
    AccessToken.Validate("Token Id", Guid.CreateSequentialGuid());
    AccessToken.Validate("Request No.", VendorRequest."No.");
    AccessToken.Validate("Vendor No.", Vendor."No.");
    AccessToken.Validate("Token Hash", AccessTokenMgt.HashToken(Format(CreateGuid())));
    AccessToken.Validate(Status, AccessToken.Status::Active);
    AccessToken.Validate("Expires At", CurrentDateTime() + 3600000);
    AccessToken.Insert(false);
  end;

  procedure SubmitAnswer(VendorRequest: Record "AMC Vendor Request"; AccessTokenId: Guid; IdempotencyKey: Text[64]; SecondSplitQuantity: Decimal; ReverseLines: Boolean; var VendorProposal: Record "AMC Vendor Proposal")
  var
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    VendorProposal.Reset();
    VendorProposal.Init();
    Clear(VendorProposal.SystemId);
    VendorProposal.Validate("Request No.", VendorRequest."No.");
    VendorProposal.Validate("Vendor No.", VendorRequest."Vendor No.");
    VendorProposal.Validate("Submitted By", 'anna.k@example.com');
    VendorProposal.Validate("External Reference", 'CC-ACK-55821');
    ProposalMgt.BeginApiSubmission(VendorProposal, AccessTokenId, IdempotencyKey);
    if ReverseLines then begin
      this.AddAnswerLine(VendorProposal, 20000, 1, "AMC Proposal Line Type"::"Substitute Item", 500);
      this.AddAnswerLine(VendorProposal, 10000, 2, "AMC Proposal Line Type"::"Split Delivery", SecondSplitQuantity);
      this.AddAnswerLine(VendorProposal, 10000, 1, "AMC Proposal Line Type"::"Split Delivery", 600);
    end else begin
      this.AddAnswerLine(VendorProposal, 10000, 1, "AMC Proposal Line Type"::"Split Delivery", 600);
      this.AddAnswerLine(VendorProposal, 10000, 2, "AMC Proposal Line Type"::"Split Delivery", SecondSplitQuantity);
      this.AddAnswerLine(VendorProposal, 20000, 1, "AMC Proposal Line Type"::"Substitute Item", 500);
    end;
    ProposalMgt.CompleteApiSubmission(VendorProposal, AccessTokenId, IdempotencyKey);
  end;

  procedure AddAnswerLine(VendorProposal: Record "AMC Vendor Proposal"; RequestLineNo: Integer; SequenceNo: Integer; LineType: Enum "AMC Proposal Line Type"; Quantity: Decimal)
  var
    ProposalLine: Record "AMC Vendor Proposal Line";
    ProposalMgt: Codeunit "AMC Proposal Mgt";
  begin
    ProposalLine.Init();
    ProposalLine.Validate("Proposal No.", VendorProposal."No.");
    ProposalLine.Validate("Request Line No.", RequestLineNo);
    ProposalLine.Validate("Sequence No.", SequenceNo);
    ProposalLine.Validate("Line Type", LineType);
    ProposalLine.Validate("Proposed Quantity", Quantity);
    ProposalLine.Validate("Proposed Delivery Date", WorkDate() + SequenceNo);
    ProposalLine.Validate("Reason Code", 'CAPACITY');
    ProposalLine.Validate("Reason Description", 'Production capacity limitation');
    if LineType = LineType::"Substitute Item" then begin
      ProposalLine.Validate("Proposed Item No.", 'ITEM-B2');
      ProposalLine.Validate("Reason Code", 'UNAVAIL');
      ProposalLine.Validate("Reason Description", 'Original item temporarily unavailable');
    end;
    ProposalMgt.InsertApiLine(ProposalLine);
  end;

  procedure NewCode(): Code[20]
  begin
    exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
  end;

  local procedure CreateRequestLine(RequestNo: Code[20]; LineNo: Integer; ItemNo: Code[20]; Quantity: Decimal)
  var
    RequestLine: Record "AMC Vendor Request Line";
  begin
    RequestLine.Init();
    RequestLine.Validate("Request No.", RequestNo);
    RequestLine.Validate("Line No.", LineNo);
    RequestLine.Validate("Purchase Line No.", LineNo);
    RequestLine.Validate("Item No.", ItemNo);
    RequestLine.Validate("Requested Quantity", Quantity);
    RequestLine.Validate("Outstanding Quantity", Quantity);
    RequestLine.Validate("Requested Delivery Date", WorkDate() + 1);
    RequestLine.Insert(false);
  end;

  local procedure EnsureReason(Reason: Code[10])
  var
    ReasonCode: Record "Reason Code";
  begin
    if ReasonCode.Get(Reason) then
      exit;
    ReasonCode.Init();
    ReasonCode.Validate(Code, Reason);
    ReasonCode.Insert(false);
  end;

  local procedure EnsureSubstitution()
  var
    ItemSubstitution: Record "Item Substitution";
  begin
    ItemSubstitution.SetRange("No.", 'ITEM-B');
    ItemSubstitution.SetRange("Variant Code", '');
    ItemSubstitution.SetRange("Substitute No.", 'ITEM-B2');
    ItemSubstitution.SetRange("Substitute Variant Code", '');
    if not ItemSubstitution.IsEmpty() then
      exit;
    ItemSubstitution.Init();
    this.EnsureItem('ITEM-B', 'PCS');
    this.EnsureItem('ITEM-B2', 'PCS');
    ItemSubstitution.Validate("No.", 'ITEM-B');
    ItemSubstitution.Validate("Substitute No.", 'ITEM-B2');
    ItemSubstitution.Insert(false);
  end;

  procedure PrepareManualNumbering()
  var
    NoSeries: Record "No. Series";
    PurchasesSetup: Record "Purchases & Payables Setup";
    InventorySetup: Record "Inventory Setup";
  begin
    if not NoSeries.Get('AMC-MANUAL') then begin
      NoSeries.Init();
      NoSeries.Validate(Code, 'AMC-MANUAL');
      NoSeries.Validate("Manual Nos.", true);
      NoSeries.Insert(false);
    end;
    if not PurchasesSetup.Get() then begin
      PurchasesSetup.Init();
      PurchasesSetup.Insert(false);
    end;
    PurchasesSetup.Validate("Vendor Nos.", NoSeries.Code);
    PurchasesSetup.Validate("Order Nos.", NoSeries.Code);
    PurchasesSetup.Modify(false);
    if not InventorySetup.Get() then begin
      InventorySetup.Init();
      InventorySetup.Insert(false);
    end;
    InventorySetup.Validate("Item Nos.", NoSeries.Code);
    InventorySetup.Modify(false);
  end;

  procedure CreatePurchaseOrder(var PurchaseHeader: Record "Purchase Header"; OrderNo: Code[20]; VendorNo: Code[20])
  var
    Vendor: Record Vendor;
    VendorPostingGroup: Record "Vendor Posting Group";
    GLAccount: Record "G/L Account";
    GLSetup: Record "General Ledger Setup";
    UserSetup: Record "User Setup";
    Assert: Codeunit "Library Assert";
  begin
    this.PrepareManualNumbering();
    this.EnsurePostingSetup();
    if not GLSetup.Get() then begin
      GLSetup.Init();
      GLSetup.Validate("Amount Rounding Precision", 0.01);
      GLSetup.Validate("Unit-Amount Rounding Precision", 0.00001);
      GLSetup.Insert(false);
    end;
    if not GLAccount.Get('AMC-PAYABLES') then begin
      GLAccount.Init();
      GLAccount.Validate("No.", 'AMC-PAYABLES');
      GLAccount.Validate("Account Type", GLAccount."Account Type"::Posting);
      GLAccount.Insert(false);
    end;
    if not VendorPostingGroup.Get('AMC-TEST') then begin
      VendorPostingGroup.Init();
      VendorPostingGroup.Validate(Code, 'AMC-TEST');
      VendorPostingGroup.Validate("Payables Account", GLAccount."No.");
      VendorPostingGroup.Insert(false);
    end;
    Assert.IsTrue(Vendor.Get(VendorNo), 'The expected vendor record must exist.');
    Vendor.Validate("Vendor Posting Group", VendorPostingGroup.Code);
    Vendor.Validate("Gen. Bus. Posting Group", 'AMC-TEST');
    Vendor.Validate("VAT Bus. Posting Group", 'AMC-TEST');
    Vendor.Modify(false);
    if not UserSetup.Get(UserId()) then begin
      UserSetup.Init();
      UserSetup.Validate("User ID", UserId());
      UserSetup.Insert(false);
    end;
    PurchaseHeader.Init();
    PurchaseHeader.Validate("Document Type", PurchaseHeader."Document Type"::Order);
    PurchaseHeader.Validate("No.", OrderNo);
    // Match the standard initialization normally reached from OnInsert or an empty No.
    PurchaseHeader.InitRecord();
    PurchaseHeader.Validate("Buy-from Vendor No.", VendorNo);
    PurchaseHeader.Insert(false);
  end;

  procedure EnsureItem(ItemNo: Code[20]; UnitOfMeasureCode: Code[10])
  var
    Item: Record Item;
    UnitOfMeasure: Record "Unit of Measure";
  begin
    if Item.Get(ItemNo) then
      exit;
    this.PrepareManualNumbering();
    this.EnsurePostingSetup();
    if not UnitOfMeasure.Get(UnitOfMeasureCode) then begin
      UnitOfMeasure.Init();
      UnitOfMeasure.Validate(Code, UnitOfMeasureCode);
      UnitOfMeasure.Insert(false);
    end;
    Item.Init();
    Item.Validate("No.", ItemNo);
    Item.Validate(Description, ItemNo);
    Item.Validate("Gen. Prod. Posting Group", 'AMC-TEST');
    Item.Validate("VAT Prod. Posting Group", 'AMC-TEST');
    Item.Validate("Inventory Posting Group", 'AMC-TEST');
    Item.Insert(false);
    Item.Validate("Base Unit of Measure", UnitOfMeasureCode);
    Item.Modify(false);
  end;

  procedure EnsurePurchaser(PurchaserCode: Code[20])
  var
    SalespersonPurchaser: Record "Salesperson/Purchaser";
  begin
    if PurchaserCode = '' then
      exit;
    if SalespersonPurchaser.Get(PurchaserCode) then
      exit;
    SalespersonPurchaser.Init();
    SalespersonPurchaser.Validate(Code, PurchaserCode);
    SalespersonPurchaser.Validate(Name, PurchaserCode);
    SalespersonPurchaser.Insert(false);
  end;

  procedure EnsureItemVariant(ItemNo: Code[20]; VariantCode: Code[10])
  var
    ItemVariant: Record "Item Variant";
  begin
    if VariantCode = '' then
      exit;
    if ItemVariant.Get(ItemNo, VariantCode) then
      exit;
    ItemVariant.Init();
    ItemVariant.Validate("Item No.", ItemNo);
    ItemVariant.Validate(Code, VariantCode);
    ItemVariant.Insert(false);
  end;

  procedure EnsureLocation(LocationCode: Code[10])
  var
    Location: Record Location;
  begin
    if LocationCode = '' then
      exit;
    if not Location.Get(LocationCode) then begin
      Location.Init();
      Location.Validate(Code, LocationCode);
      Location.Validate(Name, LocationCode);
      Location.Insert(false);
    end;
    this.EnsureInventoryPostingSetup(LocationCode, 'AMC-TEST');
  end;

  procedure EnsureCurrencyExchangeRate(CurrencyCode: Code[10])
  var
    CurrencyExchangeRate: Record "Currency Exchange Rate";
  begin
    CurrencyExchangeRate.SetRange("Currency Code", CurrencyCode);
    CurrencyExchangeRate.SetFilter("Starting Date", '..%1', WorkDate());
    if not CurrencyExchangeRate.IsEmpty() then
      exit;
    CurrencyExchangeRate.Init();
    CurrencyExchangeRate.Validate("Currency Code", CurrencyCode);
    CurrencyExchangeRate.Validate("Starting Date", WorkDate());
    CurrencyExchangeRate.Validate("Exchange Rate Amount", 1);
    CurrencyExchangeRate.Validate("Relational Exch. Rate Amount", 1);
    CurrencyExchangeRate.Validate("Adjustment Exch. Rate Amount", 1);
    CurrencyExchangeRate.Validate("Relational Adjmt Exch Rate Amt", 1);
    CurrencyExchangeRate.Insert(false);
  end;

  procedure CreateNumberSeries(): Code[20]
  var
    NoSeries: Record "No. Series";
    NoSeriesLine: Record "No. Series Line";
  begin
    NoSeries.Init();
    NoSeries.Validate(Code, this.NewCode());
    NoSeries.Validate("Default Nos.", true);
    NoSeries.Insert(false);
    NoSeriesLine.Init();
    NoSeriesLine.Validate("Series Code", NoSeries.Code);
    NoSeriesLine.Validate("Line No.", 10000);
    NoSeriesLine.Validate("Starting No.", CopyStr(NoSeries.Code, 1, 10) + '-000001');
    NoSeriesLine.Validate("Increment-by No.", 1);
    NoSeriesLine.Insert(false);
    exit(NoSeries.Code);
  end;

  local procedure EnsurePostingSetup()
  var
    GenBusinessPostingGroup: Record "Gen. Business Posting Group";
    GenProductPostingGroup: Record "Gen. Product Posting Group";
    VATBusinessPostingGroup: Record "VAT Business Posting Group";
    VATProductPostingGroup: Record "VAT Product Posting Group";
    InventoryPostingGroup: Record "Inventory Posting Group";
  begin
    if not GenBusinessPostingGroup.Get('AMC-TEST') then begin
      GenBusinessPostingGroup.Init();
      GenBusinessPostingGroup.Validate(Code, 'AMC-TEST');
      GenBusinessPostingGroup.Insert(false);
    end;
    if not GenProductPostingGroup.Get('AMC-TEST') then begin
      GenProductPostingGroup.Init();
      GenProductPostingGroup.Validate(Code, 'AMC-TEST');
      GenProductPostingGroup.Insert(false);
    end;
    if not VATBusinessPostingGroup.Get('AMC-TEST') then begin
      VATBusinessPostingGroup.Init();
      VATBusinessPostingGroup.Validate(Code, 'AMC-TEST');
      VATBusinessPostingGroup.Insert(false);
    end;
    if not VATProductPostingGroup.Get('AMC-TEST') then begin
      VATProductPostingGroup.Init();
      VATProductPostingGroup.Validate(Code, 'AMC-TEST');
      VATProductPostingGroup.Insert(false);
    end;
    if not InventoryPostingGroup.Get('AMC-TEST') then begin
      InventoryPostingGroup.Init();
      InventoryPostingGroup.Validate(Code, 'AMC-TEST');
      InventoryPostingGroup.Insert(false);
    end;
    this.EnsurePurchasePostingSetup('AMC-TEST', 'AMC-TEST', 'AMC-TEST');
  end;

  procedure EnsurePurchasePostingSetup(GenProductPostingGroupCode: Code[20]; InventoryPostingGroupCode: Code[20]; VATProductPostingGroupCode: Code[20])
  var
    GLAccount: Record "G/L Account";
    GeneralPostingSetup: Record "General Posting Setup";
    VATPostingSetup: Record "VAT Posting Setup";
  begin
    if not GLAccount.Get('AMC-POSTING') then begin
      GLAccount.Init();
      GLAccount.Validate("No.", 'AMC-POSTING');
      GLAccount.Validate("Account Type", GLAccount."Account Type"::Posting);
      GLAccount.Insert(false);
    end;
    if not GeneralPostingSetup.Get('AMC-TEST', GenProductPostingGroupCode) then begin
      GeneralPostingSetup.Init();
      GeneralPostingSetup.Validate("Gen. Bus. Posting Group", 'AMC-TEST');
      GeneralPostingSetup.Validate("Gen. Prod. Posting Group", GenProductPostingGroupCode);
      GeneralPostingSetup.Validate("Purch. Account", GLAccount."No.");
      GeneralPostingSetup.Insert(false);
    end;
    if not VATPostingSetup.Get('AMC-TEST', VATProductPostingGroupCode) then begin
      VATPostingSetup.Init();
      VATPostingSetup.Validate("VAT Bus. Posting Group", 'AMC-TEST');
      VATPostingSetup.Validate("VAT Prod. Posting Group", VATProductPostingGroupCode);
      VATPostingSetup.Validate("Purchase VAT Account", GLAccount."No.");
      VATPostingSetup.Insert(false);
    end;
    this.EnsureInventoryPostingSetup('', InventoryPostingGroupCode);
  end;

  local procedure EnsureInventoryPostingSetup(LocationCode: Code[10]; InventoryPostingGroupCode: Code[20])
  var
    InventoryPostingSetup: Record "Inventory Posting Setup";
  begin
    if InventoryPostingSetup.Get(LocationCode, InventoryPostingGroupCode) then
      exit;
    InventoryPostingSetup.Init();
    InventoryPostingSetup.Validate("Location Code", LocationCode);
    InventoryPostingSetup.Validate("Invt. Posting Group Code", InventoryPostingGroupCode);
    InventoryPostingSetup.Validate("Inventory Account", 'AMC-POSTING');
    InventoryPostingSetup.Insert(false);
  end;
}
