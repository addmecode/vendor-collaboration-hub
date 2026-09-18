# Vendor Collaboration Hub — Technical Design (V1)

The context document defines **what** and **why** at business level.
This document defines **how**: AL object model, state machines, API contract,
security, telemetry, testing, CI/CD.

Precedence: on business intent the context document wins; on technical detail
this document wins.

---

# 0. How it works — read this first

## 0.1 In one paragraph

A buyer creates a normal purchase order in Business Central and presses **Send to
Vendor Collaboration**. That freezes a copy of what was asked into a **Vendor
Request**, mints a single-purpose **access link** for it, and e-mails that link to
the vendor — no account, no installed application, nothing to provision. The vendor
clicks the link, lands on a page showing exactly that one request, and answers it
by building a **Vendor Proposal** — "600 pcs on the 15th, 400 pcs on the 20th,
reason: capacity". The proposal is a *statement of intent*, not a change: the page
hands it to an Azure Function, which re-derives who the vendor is from the link and
posts it to a custom API, where it is validated by AL code and waits.
The buyer reviews it, and either rejects it or approves it. Only approval triggers
`AMC Apply Proposal Svc`, which is the **single piece of code in the whole system
allowed to write to a purchase order**. It re-checks that the order has not changed
in the meantime, applies each proposal line through a dedicated handler, and writes
an audit entry for every field it touched. The vendor never touches ERP data; the
buyer never re-types anything.

## 0.2 The flow, end to end

```text
 BUYER (BC client)      VENDOR (browser)            BC EXTENSION (AL)
        |                      |                            |
 1. Purchase Order PO-10482    |                            |
    (status Open)              |                            |
        |                      |                            |
 2. "Send to Vendor Collaboration" ----------------> AMC Request Mgt.CreateFromOrder
        |                      |        read  Purchase Header/Line, Vendor
        |                      |        +1    AMC Vendor Request
        |                      |        +N    AMC Vendor Request Line   (the snapshot)
        |                      |        ~     Purchase Header -> locked, stays Open
        |                      |        +1    AMC Vendor Access Token   (hash, not token)
        |                      |        +4    AMC Collaboration Entry
        |                      |              Email module sends the link
        |                      |                            |
 3. e-mail: [ Review and confirm order ] ---> |             |
        |                      |                            |
        |    4. GET /r/<token>  -> Static Web App returns the page, no data yet
        |                      |                            |
        |    5. POST /api/session { token }                 |
        |                      |   Function hashes it -> GET vendorAccessTokens
        |                      |        read  AMC Vendor Access Token   (by hash)
        |                      |        ~     AMC Vendor Access Token   (access counters)
        |                      |        read  AMC Vendor Request + Line
        |                      |        +1    AMC Collaboration Entry   (LinkOpened)
        |                      | <-- 30 min session, request + lines
        |                      |     token dropped from the URL
        |                      |                            |
        |    6. POST /api/proposal  (the whole answer, one call)
        |                      |   Function adds vendorNumber + accessTokenId
        |                      |   from the token, plus the idempotency key
        |                      |   -> POST vendorProposals ------> ONE atomic call
        |                      |        +1    AMC Vendor Proposal
        |                      |        +N    AMC Vendor Proposal Line
        |                      |                            |
        |                      |                     AMC Proposal Validator
        |                      |        read  AMC Vendor Request Line, Reason Code,
        |                      |              Item Substitution, setup  (writes nothing)
        |                      |                            |
        |                      |             fail -> full rollback, 400
        |                      |               ok -> Status = Submitted
        |                      |        +2    AMC Collaboration Entry
        |                      |              business event
        |                      |                            |
 7. Teams/e-mail notification <----- Power Automate <-------+
        |                      |                            |
 8. proposal cue -> open -> Approve ---------------> AMC Proposal Decision Svc
        |                      |        ~     AMC Vendor Proposal   (decision stamp)
        |                      |                            |
        |                      |                     AMC Apply Proposal Svc
        |                      |        ~ +   Purchase Line   2 changed, 2 inserted
        |                      |        ~     Purchase Header -> Released, unlocked
        |                      |        ~     AMC Vendor Request + Line -> Closed
        |                      |        ~     AMC Vendor Access Token -> Revoked
        |                      |        +N    AMC Collaboration Entry   (one per field)
        |                      |                            |
 9. PO-10482 now has 4 lines <-----------------------------+
    with promised dates    10. reopening the link shows status "Applied"
```

`read` reads only, `+n` inserts rows, `~` modifies them. Step 8 is the only one that
writes to purchasing data, and it is the only one reached from the BC client.

Nothing in this chain lets the vendor's browser reach Business Central. The browser
talks only to the Function; the Function talks to Business Central with its own
shared application identity. Its BC permissions cover the listed tables across
vendors (§4.7); the Function limits each browser session to the request resolved
from its link. BC blocks purchase-order writes and buyer decisions by that
application. Step 6 records vendor intent; step 8, triggered by a BC buyer, is the
path that applies it to purchasing data.

**Why there is a Function between the page and the ERP.** The page is a bundle of
static files. It cannot hold the client secret the Business Central API requires,
and it cannot be trusted to state which vendor it is. The Function solves both: it
holds the credential (from Key Vault, through a managed identity) and it derives
`vendorNumber` and `requestNumber` from the access token instead of accepting them
from the browser. It also enforces the vendor-facing read scope before using its
shared BC credential; this access control is part of the trusted middle tier,
while ERP business rules remain in AL (§13). §9 covers the token and both trust
boundaries.

Step 6 is deliberately **one call carrying the whole answer**, and stays one call
all the way through to Business Central. A proposal is a single business statement
— "600 on the 15th, 400 on the 20th, and B2 instead of B" — and its validation rules
span all of its lines, so assembling it over several calls would mean validating
nothing until the last one. §8.3 covers the mechanics and the trade-off.

## 0.3 Responsibility map — who owns what

| Layer | Objects | Responsible for | Must never |
|---|---|---|---|
| **Standard BC** | `Purchase Header`, `Purchase Line`, `Vendor`, `Item`, `Item Substitution`, `Reason Code`, `No. Series` | being the source of truth for the commitment, prices, dimensions, receipts, planning | be modified directly — only extended |
| **Snapshot** | `AMC Vendor Request`, `AMC Vendor Request Line` | recording what was asked, at the moment it was asked | drift from the order silently, or be edited after sending |
| **Access** | `AMC Vendor Access Token`, `AMC Access Token Mgt` | minting, hashing, expiring and revoking the one link that lets one vendor answer one request | persist the raw token/link in AMC tables, or grant anything beyond that request |
| **Delivery** | standard Email module, `AMC Vendor Notification` | getting the link to the vendor contact; its retained message/outbox/sent-email content contains the bearer link and needs access/retention controls (§9.7) | copy the token into an AMC log, event or flow run history |
| **Intent** | `AMC Vendor Proposal`, `AMC Vendor Proposal Line` | recording what the vendor offers, immutably | change anything outside itself |
| **Rules** | `AMC Proposal Validator` + 6 line-type handlers and 1 unknown-value handler behind `AMC IProposalLineHandler` | deciding whether a proposal is legal, and how each line type maps onto purchasing data | have side effects during validation |
| **Orchestration** | `AMC Request Mgt`, `AMC Proposal Mgt`, `AMC Proposal Decision Svc`, `AMC Apply Proposal Svc` | driving the state machines and the single write path into purchasing | be callable by the integration user (permission set forbids it) |
| **Contract** | 6 API pages, `AMC Idempotency Mgt`, `AMC Proposal Validator` (error codes) | being a stable, versioned, minimal projection for the vendor API | expose standard tables or allow writes outside proposals and comments |
| **Memory** | `AMC Collaboration Entry` | the business history a buyer or auditor reads in BC: events and comments in one timeline | be edited or deleted by anyone |
| **Diagnostics** | `AMC Telemetry` → Application Insights | technical signal that survives a rollback and can be alerted on | contain secrets, tokens or be used as the audit trail |
| **Edge** | Static Web App (page), Azure Function (vendor API) | vendor UX, exchanging the link for a session, enforcing each browser session’s request/vendor scope, holding the shared BC credential, rate limiting, error translation | contain ERP business rules, or trust a vendor number that came from the browser |
| **Outside BC** | Power Automate, Power Apps | buyer notifications and buyer convenience | contain ERP business rules |

The two columns that matter most are the last one and the fact that they are
*enforced*, not documented: by the permission set (§4.7), by `Editable = false`
status fields (§5), by API page write rules (§8.2), by re-validating the access
token/request pairing in AL on vendor writes (§9.2), by Function authorization
checks on every browser read/write (§13.3), and by the absence of any `IsHandled`
escape hatch (§6.2). The shared BC permission set does not isolate reads per link.

## 0.4 Worked example — PO-10482

The scenario from the context document, traced through the actual objects.

**Starting point — standard BC, nothing custom yet.** PO-10482 is in status `Open`,
which is the only status a request can be sent from (§5.1).

| `Purchase Line` | Item | Quantity | Requested Receipt Date |
|---|---|---|---|
| 10000 | ITEM-A | 1000 | 2026-09-15 |
| 20000 | ITEM-B | 500 | 2026-09-18 |

**Step 1 — buyer sends the order to collaboration**

`AMC Request Mgt.CreateFromOrder(PurchaseHeader)` creates:

```text
AMC Vendor Request  VCR-000148
  Vendor No.            V10000 (Contoso Components)
  Purchase Order No.    PO-10482
  Status                Awaiting Vendor
  Response Deadline     2026-09-10

AMC Vendor Request Line
  10000  ITEM-A  Requested Qty 1000  Requested Date 2026-09-15  Outstanding 1000  Open
  20000  ITEM-B  Requested Qty  500  Requested Date 2026-09-18  Outstanding  500  Open
```

Side effects: `Purchase Header."AMC Collaboration Status" = Awaiting Vendor`,
`"AMC Active Request No." = VCR-000148` — which also **locks the order for editing**
until the negotiation ends (§7.3) — log entries `RequestCreated` + `RequestSent`,
telemetry `VCH0101`/`VCH0102`.

*Tables:* one row into `AMC Vendor Request` and two into `AMC Vendor Request Line`,
both copied from `Purchase Header` and `Purchase Line`; `Purchase Header` modified;
two rows into `AMC Collaboration Entry`. Nothing standard is written except those
two header fields.

**Step 2 — the link is minted and e-mailed**

`AMC Access Token Mgt.Issue(VCR-000148)` produces a 256-bit random token, stores
only its SHA-256 hash in `AMC Vendor Access Token`, and returns the raw value once
for delivery through the Email module:

```text
AMC Vendor Access Token  {b1f0...-4c2a}
  Request No.     VCR-000148
  Vendor No.      V10000
  Token Hash      9C4E...A17B      (SHA-256; no raw token in this table)
  Status          Active
  Expires At      2026-09-24 23:59
```

`AMC Vendor Notification` builds the message, and the standard Email module sends
it to `Vendor."AMC Portal Contact E-Mail"`. The body is a summary and a button
pointing at `https://vendorhub.example.com/r/0Jw7X9uF...`. Log entries `LinkIssued`
+ `LinkSent`, telemetry `VCH0120`/`VCH0121`.

*Tables:* one row into `AMC Vendor Access Token` — holding the hash, never the token
— `Vendor` read for the address and the language, two rows into
`AMC Collaboration Entry`; the standard Email module stores the message body
containing the full link, with Email Outbox or Sent Email tracking according to
delivery state (§9.7). Hash-only storage applies to the AMC tables.

**Step 3 — the vendor opens the link**

The Static Web App serves the page for `/r/<token>`; the page immediately
`POST`s the token to `/api/session`. The Function hashes it, looks it up
(an exact `tokenHash` equality filter, with `$select` excluding the hash — §8.2),
finds it `Active` and
unexpired, calls `registerAccess` — which writes a `LinkOpened` entry to the
timeline and stamps `Last Accessed At` — and returns a 30-minute session plus the
request:

`GET vendorRequests?$filter=number eq 'VCR-000148' and vendorNumber eq 'V10000'&$expand=vendorRequestLines`
uses identities resolved by the Function from the link, not supplied by the
browser, and returns the request JSON of §8.3. The raw token is dropped from the browser URL at
this point (§9.4).

*Tables:* `AMC Vendor Access Token` read by hash and modified in place (access
counters only, never the status), `AMC Vendor Request` and `AMC Vendor Request Line`
read, one row into `AMC Collaboration Entry`. Nothing in this step touches
purchasing data at all.

**Step 4 — the vendor answers, in one call**

The vendor assembles the answer in the page (a work-in-progress answer stays in the
browser, never in BC). When they press *Send*, the page makes one
`POST /api/proposal`; the Function attaches `vendorNumber` and `accessTokenId` from
the session — never from the request body — and forwards a **single**
`POST vendorProposals` carrying the header and all three lines nested, with an
`idempotencyKey` (§8.3):

```text
AMC Vendor Proposal  VCP-000091

AMC Vendor Proposal Line
  10000  ReqLine 10000  Split Delivery   Seq 1  Qty 600  Date 2026-09-15  CAPACITY
  20000  ReqLine 10000  Split Delivery   Seq 2  Qty 400  Date 2026-09-20  CAPACITY
  30000  ReqLine 20000  Substitute Item  Seq 1  Qty 500  Date 2026-09-18  UNAVAIL
                                          Proposed Item No. ITEM-B2
```

*Tables:* one row into `AMC Vendor Proposal` and three into
`AMC Vendor Proposal Line`, in a single transaction with the validation below. The
purchase order is not touched — that is the whole point of the proposal being a
statement of intent.

**Step 5 — validation, inside the same transaction**

Before the insert is allowed to commit, the API page checks that the access token
is still active and belongs to VCR-000148, then `AMC Proposal Validator` checks,
without writing anything:

- 600 + 400 = 1000 ≤ outstanding 1000 on request line 10000 ✔
- 2 splits ≤ `Max Splits per Line` ✔
- both dates ≥ WORKDATE ✔
- `CAPACITY` and `UNAVAIL` exist in `Reason Code` ✔
- `Allow Item Substitution` = true and (ITEM-B → ITEM-B2) exists in the standard
  `Item Substitution` table ✔ — *if it did not, the whole POST is rejected with
  `VCH-VAL-0030`, nothing is written, and the vendor sees the reason immediately*

Notice that the first two checks are **statements about the answer as a whole**.
This is the concrete reason the proposal arrives in one call: had the three lines
been POSTed separately, each would have passed on its own and the vendor would only
have learned the answer was invalid after the last request.

*Tables read, none written:* `AMC Vendor Request Line` for the outstanding
quantities, `AMC Collaboration Setup` for `Max Splits per Line` and
`Allow Item Substitution`, `Reason Code` for `CAPACITY` and `UNAVAIL`, and the
standard `Item Substitution` for the ITEM-B → ITEM-B2 pair. The validator writes
nothing, which is what lets the same code run from the API, from the buyer's approve
action and from a test.

Result: `201 Created` with `Status = Submitted`, log entries `ProposalReceived` +
`ProposalSubmitted`, telemetry `VCH0201`/`VCH0203`, business event
`VendorProposalSubmitted` → Power Automate → Teams message to the buyer with a
deep link.

**Step 6 — buyer approves**

`AMC Proposal Decision Svc.Approve` checks permissions without writing, then runs
`AMC Apply Proposal Svc` through `Codeunit.Run` with its Boolean result captured
(§7.1). The approval status, decision stamp and approval log are written inside
that codeunit, in the same transaction as the order changes:

1. The order is still locked by VCR-000148, so it is exactly as the vendor saw it.
   *(A colleague who needed to change line 10000 yesterday would have had to unlock
   the order first, which cancels the request — and the vendor's link would have
   stopped working before they could answer at all.)*
2. Line-by-line dispatch through the interface, inside the suppression window that
   lets apply write through the lock — the orchestrator never knows what "split"
   means:

| Proposal line | Handler | Effect on the purchase order |
|---|---|---|
| Seq 1, 600 / 09-15 | `AMC Split Delivery Handler` | line 10000: `Validate(Quantity, 600)`, `Validate("Promised Receipt Date", 2026-09-15)` |
| Seq 2, 400 / 09-20 | `AMC Split Delivery Handler` | inserts line **15000** (the midpoint of the free gap after 10000, so the split stays next to its origin), copying ITEM-A, location, UoM and dimensions, `Quantity 400`, `Promised Receipt Date 2026-09-20`, stamped `AMC Origin Proposal No. = VCP-000091` |
| Seq 1, ITEM-B2 500 | `AMC Substitute Item Handler` | inserts line **25000** for ITEM-B2 with `Quantity 500`, `Promised Receipt Date 2026-09-18`; original line 20000 set to `Quantity 0` / cancelled, both stamped with the origin proposal |

3. Request lines recalculated (`Confirmed 1000`, `Outstanding 0`, status
   `Confirmed`); the order is **released** — the vendor's answer is what commits it;
   request → `Closed` and `AMC Active Request No.` cleared, so the order is editable
   again and can now be received against.
4. Proposal → `Applied`; one log entry per changed field; telemetry `VCH0220`
   with duration and line count.

*Tables:* `Purchase Line` — two rows modified and two inserted; `Purchase Header`
modified twice, once by the standard release codeunit and once to clear the lock;
`AMC Vendor Request Line` and `AMC Vendor Request` modified; `AMC Vendor Access
Token` revoked; `AMC Vendor Proposal` and `AMC Vendor Proposal Line` stamped as
applied; a row into `AMC Collaboration Entry` for every field that changed. This is
the only step in the whole flow that writes to purchasing data, and it is reached
only from the BC client.

**Result — standard BC again, and nothing was typed by hand**

| `Purchase Line` | Item | Quantity | Requested | Promised | Origin |
|---|---|---|---|---|---|
| 10000 | ITEM-A | 600 | 2026-09-15 | 2026-09-15 | VCP-000091 |
| 15000 | ITEM-A | 400 | 2026-09-15 | 2026-09-20 | VCP-000091 |
| 20000 | ITEM-B | 0 | 2026-09-18 | | VCP-000091 (cancelled) |
| 25000 | ITEM-B2 | 500 | 2026-09-18 | 2026-09-18 | VCP-000091 |

The order is `Released`, and receipts, planning, availability and reporting see four
ordinary purchase lines — none of them knows this extension exists. The negotiation that produced them is
readable on the `AMC Collab Timeline` and answerable in an audit.

**What the example demonstrates**

| Question | Where this example answers it |
|---|---|
| Why can't the vendor just PATCH the purchase line? | steps 4–6: the vendor's write and the ERP write are different operations, separated by a human decision and a permission set |
| What if the order changed meanwhile? | it could not: step 1 locked it, and only apply or a deliberate unlock releases it (§7.3) |
| How do you authenticate someone who is not a user of any of your systems? | step 2 — a hashed, expiring, revocable token scoped to one request, re-checked in AL on every write |
| Why not just put the form in the e-mail? | step 3 — mail clients strip forms and scripts; the link is the only part of an e-mail that behaves the same everywhere |
| Where does business logic live? | `AMC Proposal Validator` and the six handlers, all in AL, all unit-tested — not in the Function |
| How is the API kept stable? | step 3 — a projection with its own field names, not `Purchase Line` |
| Why is this not duplicating BC? | the result table — plain purchase lines, standard `Promised Receipt Date`, standard `Item Substitution` |

---

# 1. Platform assumptions

| Topic | Decision |
|---|---|
| Platform | Business Central **SaaS**, cloud sandbox for development |
| Extension type | PTE shape, written to AppSource rules (analyzers on) |
| `application` / `runtime` | Set to the version of your actual sandbox — verify in VS Code, do not copy from a blog |
| Base app changes | Forbidden. Extensions + events only |
| Publisher affix | `AMC` on every object, and on every field, control and enum value added to a standard object — in the **name**, never in a caption |
| Solution prefix | `VCH` on identifiers that belong to this solution rather than to the publisher: error codes, telemetry event ids and telemetry dimensions |
| Data classification | Mandatory on every field. Collaboration data = `CustomerContent`, setup = `SystemMetadata` |
| Features | `NoImplicitWith`, `TranslationFile` |
| Secret storage | The BC client secret stays in Key Vault for the Function. AMC token data stores only the access-link hash; the standard Email module retains the full bearer link in message content (§9.7) |

**Why "PTE shape, AppSource rules":** the app will never hit AppSource, so a free
ID range and manual deploy are fine. But the *rules* of AppSource — affixes, no
base-app edits, `AppSourceCop`, AL permission sets, upgrade codeunits — are exactly
the habits that separate an on-prem developer from a cloud developer. Turning the
analyzers on costs nothing and prevents on-prem reflexes.

**The affix names objects; it never reaches a user.** `AppSourceCop` requires `AMC`
on every object and on everything this app adds to a standard one, so it is there in
the name a developer reads in AL and in the object designer. That is the only place
it belongs. Everything with a user-facing label carries an explicit `Caption`
without it:

```al
table 50101 "AMC Vendor Request"
{
    Caption = 'Vendor Request';
    ...
}

tableextension 50100 "AMC Purchase Header Ext" extends "Purchase Header"
{
    fields
    {
        field(50100; "AMC Active Request No."; Code[20])
        {
            Caption = 'Active Request No.';
            DataClassification = CustomerContent;
        }
    }
}
```

A buyer sees *Vendor Request*, *Active Request No.* and *Origin Proposal No.* — never a
three-letter prefix explaining whose code it is. The rule covers everything with a
label, and the ones that get forgotten are worth naming: **permission sets** (their
caption is what an administrator picks from), **enum values** (`AMC Vendor
Collaboration` on the standard `Email Scenario` enum is captioned *Vendor
Collaboration* in *Email Accounts* setup), **page actions**, and **fields added to
standard tables**, which is where the affix is most visibly wrong because it sits
next to Microsoft's own fields on the same page.

`TranslationFile` (above) and the UICop rule requiring a caption on every control
are what keep this from drifting; the ruleset promotes a missing caption to an
error, so a forgotten one fails the build rather than shipping (§12.2).

**Two prefixes, two jobs.** `AMC` identifies the publisher, and it is what
`AppSourceCop` enforces: it keeps this company's objects from colliding with
Microsoft's or with another publisher's, so it belongs on object names and on
anything added to a standard object. `VCH` identifies *this solution* among the
publisher's others, and belongs on identifiers whose reader has to tell one system's
signal from another's:

| | Prefix | Examples |
|---|---|---|
| AL object names, and anything added to a standard object | `AMC` | `AMC Vendor Request`, `AMC Active Request No.`, `AMC Collaboration Buyer` |
| Error codes | `VCH` | `VCH-VAL-0012`, `VCH-AUT-0003` |
| Telemetry event ids and dimensions | `VCH` | `VCH0201`, `vchRequestNo` |

The split matters where the two meet. A shared Application Insights resource
carrying several of this publisher's extensions needs `VCH0201` to mean one thing;
`AMC0201` would eventually mean two. The Function parses `VCH-` off an error message
(§8.4) for the same reason — it is talking to this solution, not to this company.

Neither prefix is ever shown to a Business Central user.

---

# 2. Solution shape

```text
bc/
  vendor-collaboration-hub/ -> "Vendor Collaboration Hub"        idRanges 50100-50129
  test/   -> "Vendor Collaboration Hub Tests"  idRanges 50130-50149
```

**Two apps: main + test.**

Rejected:
- *Tests inside the main app* — ships test code and test-library dependencies to production.
- *Three apps (Core / API / UI)* — app splitting is justified by different consumers,
  licensing or release cadence. None applies here. It would add cross-app version
  management for zero benefit. Module boundaries are enforced by feature folders and
  `internal` access modifiers instead, so a split stays possible later.

## 2.1 `app.json` (main)

```jsonc
{
  "id": "<new GUID>",
  "name": "Vendor Collaboration Hub",
  "publisher": "Adrian Oth",
  "version": "1.0.0.0",
  "application": "<your BC application version>",
  "runtime": "<matching AL runtime>",
  "idRanges": [ { "from": 50100, "to": 50129 } ],
  "features": [ "NoImplicitWith", "TranslationFile" ],
  "target": "Cloud",
  "resourceExposurePolicy": {
    "allowDebugging": true,
    "allowDownloadingSource": false,
    "includeSourceInSymbolFile": false
  }
}
```

Test app adds `"test"` dependencies on `Library Assert`, `Any`,
`Tests-TestLibraries`, plus a dependency on the main app.

## 2.2 Folder structure — feature-based

```text
bc/vendor-collaboration-hub/src/
  Setup/           AMCCollaborationSetup.Table.al | .Page.al          (GetSetup is on the table)
  Request/         AMCVendorRequest(.Line).Table.al | 2 status enums | AMCRequestMgt.Codeunit.al | 3 pages
  Proposal/        AMCVendorProposal(.Line).Table.al | 2 enums | Mgt / Validator / DecisionSvc
                   AMCValidationResult.Codeunit.al | AMCIdempotencyMgt.Codeunit.al | 3 pages
  Apply/           AMCIProposalLineHandler.Interface.al | AMCApplyProposalSvc.Codeunit.al
                   AMCPurchaseLineBuilder.Codeunit.al | 6 line-type handlers + AMCUnknownLineHandler.Codeunit.al
  Access/          AMCVendorAccessToken.Table.al | status enum | AMCAccessTokenMgt.Codeunit.al
                   AMCTokenExpiryJob.Codeunit.al | 2 pages
  Notification/    AMCVendorNotification.Codeunit.al | AMCVendorEmailBuilder.Codeunit.al
                   AMCEmailScenario.EnumExt.al
  Purchasing/      3 TableExt | 5 PageExt | AMCPurchaseEvents.Codeunit.al  (subscribers only)
                   AMCOrderLockMgt.Codeunit.al
  Collaboration/   AMCCollabEntry.Table.al | 2 enums | AMCCollabLog.Codeunit.al | AMCCollabTimeline.Page.al
  Api/             6 API pages
  Integration/     AMCBusinessEvents.Codeunit.al
  Telemetry/       AMCTelemetry.Codeunit.al
  Install/         AMCInstall.Codeunit.al | AMCUpgrade.Codeunit.al
  Permissions/     4 .PermissionSet.al
```

File naming: `<ObjectName>.<ObjectType>.al`.

**Why feature folders and not `/Tables`, `/Pages`, `/Codeunits`:** an object-type
layout scatters one business capability across the repo. Feature folders keep a
change to "split delivery" inside one directory, produce readable PR diffs, and
make a future app split mechanical instead of archaeological.

---

# 3. Domain model

```text
Purchase Order (STANDARD BC — owner of the commitment)
   | 1 : 0..1 active
   v
AMC Vendor Request           snapshot of what was asked
   |  \
   |   \ 1 : 0..1 active (1 : N over time)
   |    v
   |   AMC Vendor Access Token   the link that lets this vendor answer
   |
   | 1 : N
   v
AMC Vendor Request Line      snapshot per purchase line
   ^ referenced by
   |
AMC Vendor Proposal          what the vendor offers (1 : N per request)
   | 1 : N
   v
AMC Vendor Proposal Line     one proposed fulfillment element
```

Modeling rules:

1. **Vendor Request is a snapshot, not a second source of truth.** It records what
   was asked at send time, so a vendor answer can always be interpreted against the
   question that was actually asked.
2. **A submitted proposal is immutable.** A vendor changing their mind submits a new
   proposal; the previous one becomes `Superseded`. This is what makes the
   negotiation history real instead of a mutable last-write-wins field.
3. **A proposal line never writes to a Purchase Line.** Only `AMC Apply Proposal Svc`
   touches purchasing data, and only after an explicit buyer decision.
4. **No duplication of standard purchasing data.** Item master, vendor master,
   prices, dimensions, receipt tracking stay in standard tables.
5. **The access token is a credential, not a document.** It is stored hashed, it
   expires, it can be revoked and re-issued, and it grants exactly one right:
   answering the request it was minted for. Business Central owns it, because
   Business Central owns the request whose lifetime it shares.

## 3.1 Standard BC objects reused instead of reimplemented

| Need | Standard object used | Why not custom |
|---|---|---|
| Vendor's confirmed delivery date | `Purchase Line."Promised Receipt Date"` | This field already means "date promised by the vendor". A `AMC Confirmed Date` would fork the truth and break Order Promising, planning and Expected Receipt Date recalculation |
| Buyer's requested date | `Purchase Line."Requested Receipt Date"` | Same reason |
| Change reason | `Reason Code` (standard table) | Exists, has a setup page, already used across BC |
| Alternative item validation | `Item Substitution` (standard table) | A vendor may only propose an item registered as a substitute — reuses master-data governance instead of inventing it |
| What a line costs after a change | standard price calculation, triggered by `Validate()` | Prices, price lists, quantity breaks and line discounts are a whole BC subsystem with its own setup and its own date logic. Carrying the old price forward, or computing a new one here, would make this extension an opinion about pricing (§7.2) |
| Numbering | `No. Series` module | Standard, per-company setup, manual/automatic |
| Release | `Release Purchase Document` codeunit | An approved proposal releases the order through the standard codeunit, so every standard release check runs — never around it |
| Gating receipt, posting and invoicing on a vendor confirmation | `Purchase Header.Status` (`Open` / `Released`) | `Released` already means "committed, and may be acted on", and already gates posting. Making an approved proposal the thing that releases the order gets that gate for free, instead of a custom confirmation status and a custom block on the posting routines (§5.1) |
| Sending the link to the vendor | `Email` module (System Application) | accounts, connectors, e-mail scenarios, Sent Emails and outbox retry already exist; message content retains the bearer link and is covered by §9.7. A custom sender would add another delivery store to control |
| Buyer notifications | Power Automate over business events | Not an ERP concern |

This table is the direct answer to design principle 10.1.

---

# 4. Object map

## 4.1 ID allocation and the licence budget

**Available range: 50100–50149 — 50 IDs per object type.**

Object-type ID spaces are independent in AL, and a Business Central licence grants
object ranges **per object type**, so table 50100, codeunit 50100 and page 50100 all
coexist and each type gets its own 50 slots. What is *not* independent is the main
app versus the test app: both are installed in the same tenant, so their objects
share one ID space per type and must fit in the same 50 slots together.

> Confirmed against this project's licence: the range is granted per object type.
> The counts below depend on that, so it is worth knowing the dependency exists —
> under a licence granting 50 IDs in total across all types this model would not fit,
> and could not be made to without giving up the handler interface, the per-handler
> test suites or the audit table. Any environment this ships to needs the same
> reading (in BC: *Help and Support → Licence information*).

| Type | App | Test | Total | IDs used | Free |
|---|---|---|---|---|---|
| Table | 7 | 0 | 7 | 50100–50106 | 43 |
| TableExtension | 3 | 0 | 3 | 50100–50102 | 47 |
| Enum | 8 | 0 | 8 | 50100–50107 | 42 |
| EnumExtension | 1 | 0 | 1 | 50100 | 49 |
| Codeunit | 26 | 15 | 41 | 50100–50125, 50130–50144 | 9 |
| Page | 17 | 0 | 17 | 50100–50110 (UI), 50120–50125 (API) | 33 |
| PageExtension | 5 | 0 | 5 | 50100–50104 | 45 |
| PermissionSet | 4 | 0 | 4 | 50100–50103 | 46 |
| Interface | 1 | 0 | 1 | *no ID consumed* | — |

**86 objects, 41 in the busiest type.** Codeunits are the constraint, which is
correct — that is where the behaviour lives, and it is where splitting things up
actually buys something.

Allocation convention inside each type: the app takes `50100–50129`, the test app
takes `50130–50149`. Both blocks are used from the bottom up, so the free IDs stay
contiguous at the top of each block.

### The rule for adding an object

**An object exists when it has its own reason to be tested, replaced, or reasoned
about.** That is the whole rule. Its two halves matter equally:

- *Tested* — if a behaviour can only be exercised through three other objects and a
  purchase order, it does not really have tests, it has integration checks that
  happen to touch it. Pulling it out is how it gets asserted directly.
- *Replaced* — if two callers need it to behave differently, or one caller is a test
  that needs it to do nothing, it is a seam and it belongs behind its own object.

The range is there to be spent. Holding IDs back for versions that do not exist yet
buys nothing today and costs testability now, so the counts above are what the
design needs rather than what fits comfortably. Ten free codeunit IDs is enough
headroom; if a future version needs more than that, the honest answer is a wider
range, not a worse V1.

What this rule does **not** licence is an object per noun. These stay folded in,
and for reasons that have nothing to do with counting:

- `GetSetup` is a procedure on `AMC Collaboration Setup`, because that is where
  standard BC puts it and a wrapper would only forward.
- Upgrade tags are constants in `AMC Upgrade`, next to the procedures guarded by
  them; separating a tag from its migration is how they drift.
- Error labels live in `AMC Proposal Validator`, next to the code that raises them.
  A central catalogue would be a second place to update and a second place to
  forget — `docs/api/error-codes.md` is generated from these labels (§8.4), which is
  the copy that has to stay in sync.
- Telemetry event ids are `Label` constants in `AMC Telemetry` rather than an enum,
  because nothing dispatches on them and an enum would demand captions for
  identifiers no user ever sees.
- The buyer worklist is `AMC Vendor Proposals` opened with a status filter, not a
  second page: two pages over one table is two places to fix a column.
- There is one interface, `AMC IProposalLineHandler`, with six business handlers
  and one defensive handler for unknown persisted ordinals (§6.1). A second interface for notification transport would have one
  implementation and one caller, which is a guess about the future dressed as
  architecture.

## 4.2 Tables

### `AMC Collaboration Setup` (50100) — singleton

**Responsibility:** one place where an administrator turns the whole feature on, sets its guardrails, and picks number series. Nothing else in the app hardcodes a limit.

| Field | Type | Notes |
|---|---|---|
| Primary Key | Code[10] | always blank |
| Enabled | Boolean | master switch; API rejects writes when false |
| Request Nos. / Proposal Nos. | Code[20] | `No. Series` |
| Default Response Days | Integer | computes `Response Deadline` |
| Allow Item Substitution | Boolean | feature flag for the `Substitute Item` line type |
| Allow Quantity Increase | Boolean | default **false** — a vendor offering *more* than ordered is a commercial decision, not a fulfillment answer |
| Max Splits per Line | Integer | guardrail against a client generating 500 delivery splits |
| Require Reason Code | Boolean | forces `Reason Code` on every non-Confirm line |
| Portal Base URL | Text[250] | root of the vendor response page; an access link is `<base>/r/<token>` |
| Portal Support E-Mail | Text[80] | the one address shown when a link does not work. Static and identical for every failure, on purpose (§9.5) |
| Link Validity Days | Integer | how long an access link stays usable; default 14. Must not be shorter than `Default Response Days` — a link that dies before the answer is due is a guaranteed support call, so the field validates it (§9.2) |
| Attach Order PDF | Boolean | attach the standard purchase order report to the vendor e-mail |
| Telemetry Verbosity | Enum `Verbosity` | standard enum |

### `AMC Vendor Request` (50101)

**Responsibility:** the question. It freezes what the buyer asked of one vendor for one purchase order, so every later answer can be judged against it.

| Field | Type | Notes |
|---|---|---|
| No. | Code[20] | PK, from `Request Nos.` |
| Vendor No. | Code[20] | `TableRelation = Vendor` |
| Vendor Name | Text[100] | FlowField, lookup on Vendor |
| Purchase Order No. | Code[20] | `TableRelation = "Purchase Header"."No." where("Document Type" = const(Order))` |
| Status | Enum `AMC Request Status` | §5.1, not editable on pages |
| Purchaser Code | Code[20] | `TableRelation = "Salesperson/Purchaser"` |
| Assigned User ID | Code[50] | `TableRelation = User."User Name"` |
| Sent Date Time | DateTime | set by `AMC Request Mgt.Send` |
| Response Deadline | Date | `Sent Date` + vendor or setup response days |
| Closed Date Time | DateTime | |
| External Reference | Text[50] | vendor's own reference, typed on the vendor page |
| Currency Code | Code[10] | copied from the order for display |
| Language Code | Code[10] | snapshot of the language this vendor was addressed in — `Vendor."Language Code"`, or the company's when blank. The e-mail and the page both follow it (§13.4) |
| Open Proposal Count | Integer | FlowField, proposals in `Submitted`/`In Review` |
| Line Count | Integer | FlowField |

| Key | Purpose |
|---|---|
| `No.` | primary key |
| `Vendor No., Status` | "the open requests of this vendor" |
| `Purchase Order No., Status` | find the one active request for an order, and enforce that there is only one (§5.1) |
| `Status, Response Deadline` | overdue-request list and escalation flow |

### `AMC Vendor Request Line` (50102)

**Responsibility:** the per-item detail of the question, plus the running tally of how much of it the vendor has already confirmed.

| Field | Type | Notes |
|---|---|---|
| Request No. | Code[20] | PK part |
| Line No. | Integer | PK part |
| Purchase Line No. | Integer | link back to `Purchase Line."Line No."` |
| Item No. | Code[20] | snapshot |
| Variant Code | Code[10] | snapshot |
| Description | Text[100] | snapshot |
| Location Code | Code[10] | snapshot |
| Unit of Measure Code | Code[10] | snapshot |
| Requested Quantity | Decimal | snapshot |
| Requested Delivery Date | Date | snapshot of `Requested Receipt Date` |
| Confirmed Quantity | Decimal | sum of applied proposal lines |
| Outstanding Quantity | Decimal | `Requested - Confirmed` |
| Status | Enum `AMC Request Line Status` | recalculated after every apply |

| Key | Purpose |
|---|---|
| `Request No., Line No.` | primary key |
| `Request No., Purchase Line No.` | unique lookup during apply |
| `Status` | outstanding-lines filtering |

### `AMC Vendor Proposal` (50103)

**Responsibility:** the answer. It carries the vendor's identity, the version of the order they answered, the idempotency key of the call that created it, and the buyer's decision.

| Field | Type | Notes |
|---|---|---|
| No. | Code[20] | PK, from `Proposal Nos.` |
| Request No. | Code[20] | `TableRelation = "AMC Vendor Request"` |
| Vendor No. | Code[20] | denormalized — API filtering and permission checks |
| Purchase Order No. | Code[20] | denormalized — lookup and telemetry |
| Status | Enum `AMC Proposal Status` | §5.2, not editable on pages |
| **Idempotency Key** | Text[64] | supplied by the caller, unique per vendor (§8.5) |
| Submitted Date Time | DateTime | |
| Submitted By | Text[100] | the name and address the vendor typed when submitting — BC has no user object for a vendor |
| Decision Date Time | DateTime | |
| Decision User ID | Code[50] | |
| Decision Reason | Text[250] | |
| Applied Date Time | DateTime | |
| Apply Attempt Count | Integer | |
| Last Error Code | Code[20] | e.g. `VCH-APL-0003` |
| Last Error Message | Text[250] | |
| Correlation Id | Guid | joins BC telemetry with the page and Function telemetry for the same action |
| Superseded By | Code[20] | self-relation to the replacing proposal |

| Key | Purpose |
|---|---|
| `No.` | primary key |
| **`Vendor No., Idempotency Key`** | **unique** — enforces idempotency at database level |
| `Request No., Status` | proposals of one request |
| `Status, Submitted Date Time` | buyer worklist, oldest first |

### `AMC Vendor Proposal Line` (50104)

**Responsibility:** one concrete fulfillment element of the answer. Its `Line Type` decides which handler will later translate it into purchasing data.

| Field | Type | Notes |
|---|---|---|
| Proposal No. | Code[20] | PK part |
| Line No. | Integer | PK part |
| Request Line No. | Integer | which requested line this answers |
| Line Type | Enum `AMC Proposal Line Type` | implements `AMC IProposalLineHandler` (§6.1) |
| Sequence No. | Integer | ordering of splits within one request line |
| Proposed Item No. | Code[20] | only for `Substitute Item` |
| Proposed Variant Code | Code[10] | |
| Proposed Quantity | Decimal | |
| Proposed Delivery Date | Date | |
| Reason Code | Code[10] | `TableRelation = "Reason Code"` (standard table) |
| Reason Description | Text[250] | free text from the vendor |
| Applied | Boolean | set when the handler has written this line to the order. A decision is made on the whole proposal (§5.2), and apply is one transaction, so a line has no outcome of its own to record |
| Applied Purchase Line No. | Integer | which purchase line this produced |

| Key | Purpose |
|---|---|
| `Proposal No., Line No.` | primary key |
| `Proposal No., Request Line No., Sequence No.` | apply order and per-request-line grouping |

### `AMC Collaboration Entry` (50105) — append-only timeline

**Responsibility:** the business memory of one negotiation. Every state change, every applied field change and every human remark, in one chronological stream — readable in BC, never editable by anyone.

| Field | Type | Notes |
|---|---|---|
| Entry No. | BigInteger | PK, `AutoIncrement = true` |
| Source Type | Enum `AMC Source Type` | Request / Proposal |
| Source No. | Code[20] | |
| Source Line No. | Integer | 0 = document-level entry |
| Entry Type | Enum `AMC Collab Entry Type` | `Comment` plus every process event — see §4.4 |
| Actor Type | Enum `AMC Actor Type` | Buyer / Vendor / System / Integration |
| Actor Name | Text[100] | the name the vendor gave, for vendor actions |
| User ID | Code[50] | BC user; blank for vendor and system entries |
| **Visible to Vendor** | Boolean | `false` = internal note or internal-only event, never returned by the API |
| Field Name | Text[80] | filled for field-level changes recorded during apply |
| Old Value | Text[250] | |
| New Value | Text[250] | |
| Description | Text[250] | the comment text, or the reason / error code / context of an event |
| Correlation Id | Guid | same value as the telemetry dimension |
| Date Time | DateTime | |

| Key | Purpose |
|---|---|
| `Entry No.` | primary key |
| `Source Type, Source No., Date Time` | the timeline of one document, in order |
| `Entry Type, Date Time` | "every forced unlock this month" style queries |
| `Source Type, Source No., Visible to Vendor` | what the API may return |

`Entry Type = Comment` carries a human remark in `Description`; every other value
records a process event. `Visible to Vendor = false` covers both an internal buyer
note and an event the vendor has no business seeing, and the API page filters on it
at page level for this API endpoint. The Function additionally restricts the
source request/proposal to the current session. The page projection and visibility
filter are not per-link table permissions for the shared S2S identity (§4.7).

The page over this table is `Editable = false`, `InsertAllowed = false`,
`ModifyAllowed = false`, `DeleteAllowed = false`. Only `AMC Collab Log` writes to
it, and it never updates or deletes.

**Entries are kept indefinitely, and nothing in the app can remove them.** No
permission set grants `D` on this table (§4.7), `AMC Collab Log` has no delete path,
and the pages expose none. "Indefinitely" is therefore an enforced property rather
than a policy someone is trusted to follow.

The volume makes that affordable. Rows accrue per negotiation step, not per
transaction and not per API call: a request that is sent, answered, commented on
twice, approved and applied produces on the order of twenty rows. A company running
a thousand collaborated purchase orders a year adds tens of thousands of rows a
year, which is nothing for a BC table with three keys. The thing that *would* grow
without bound is a technical log — one row per HTTP call, per retry, per validation
failure — and that is exactly what lives in Application Insights instead, under its
own retention (§10). Splitting the two channels is what makes indefinite retention
of this one a non-question.

**The table is deliberately not registered with the Retention Policy module.**
Registering it would put a delete on a standard setup page, and hand an
administrator a supported way to erase an audit trail that every other rule here
protects. If a retention requirement ever genuinely arrives, that is a decision to
revisit on its merits — not a capability to leave lying around in advance.

**Why one table and not separate audit and comment tables:** they have the same
key, the same append-only rule and the same lifetime, and the buyer reads them
together — "vendor proposed 600, buyer asked why, vendor answered, buyer approved"
is one thread. Splitting it would force every reader to interleave two lists by
timestamp, and would put the same append-only rule in two places.

**Why a custom table and not just telemetry:** this is *business* history the buyer
must be able to read inside BC. Application Insights is for *technical* diagnostics,
is not queryable from the BC client, has retention limits, and is not part of the
audit trail. The two are complementary — §10 covers the split.

**Why there is no separate idempotency ledger:** the unique key
`Vendor No. + Idempotency Key` on `AMC Vendor Proposal` (§4.2) already is the
ledger. A failed submit rolls the whole insert back (§8.3) and releases the key with
it, which is the semantics you want — a rejected proposal should be retryable under
the same key. Rejected attempts remain visible in telemetry (`VCH0202`).

### `AMC Vendor Access Token` (50106)

**Responsibility:** the credential. It is the one thing that lets a person who has
no identity in any of these systems answer one specific request — and the one thing
that can be taken away again.

| Field | Type | Notes |
|---|---|---|
| Token Id | Guid | PK; the value the Function puts in a session and BC checks on every vendor write. Not secret |
| Request No. | Code[20] | `TableRelation = "AMC Vendor Request"` |
| Vendor No. | Code[20] | denormalized, so a write can be scoped without reading the request |
| **Token Hash** | Text[64] | SHA-256 of the raw token, uppercase hex. **No raw token or full access link is persisted in this table or other AMC tables**; retained Email message bodies are a separate copy (§9.7) |
| Status | Enum `AMC Access Token Status` | Active / Expired / Revoked / Superseded |
| Issued At | DateTime | |
| Expires At | DateTime | `Issued At` + `Link Validity Days` |
| Sent To E-Mail | Text[80] | the address the link went to — the buyer needs to see where it was sent |
| Sent At | DateTime | stamped when the Email module accepted the message |
| First Accessed At | DateTime | |
| Last Accessed At | DateTime | |
| Access Count | Integer | |
| Revoked At / Revoked By | DateTime / Code[50] | |
| Revocation Reason | Text[250] | |

| Key | Purpose |
|---|---|
| `Token Id` | primary key |
| **`Token Hash`** | **unique** — the only lookup path the Function has |
| `Request No., Status` | the active link of a request; used when re-sending |
| `Status, Expires At` | the job that expires stale links |

Rules the table exists to enforce:

- **AMC tables store no raw token.** `AMC Access Token Mgt.Issue` returns the raw
  token once to the notification code, which builds the e-mail link. The standard
  Email module retains that link in message content for delivery/retry and sent-mail
  viewing. This hash-only rule does not cover Email storage, provider archives or
  mailboxes (§9.7).
- **Opening the link is not a state change.** Accessing it stamps counters and
  writes a `LinkOpened` timeline entry, nothing else. Tokens are therefore
  multi-use: the vendor can come back, and a corporate mail scanner that pre-fetches
  the URL does not consume the link. That is why this table counts accesses rather
  than marking one as spent.

When a token stops working — expiry, revocation, supersession on re-send — is the
same subject as how one is validated, and §9.2 covers them together.

**Why the token lives in Business Central and not in Azure:** it shares its
lifetime with the vendor request, and the request is a BC record. Applying the
context document's ownership test — *which system owns this record?* — the answer is
the same system that decides when the negotiation is over. Keeping it in Azure
would mean a second store to revoke against, and a way for a link to outlive the
request that justified it.

## 4.3 Table extensions

### `AMC Purchase Header Ext` (50100, extends `Purchase Header`)

| Field | Type | Purpose |
|---|---|---|
| AMC Collaboration Status | Enum `AMC Request Status` | at-a-glance state on the order list — mirrors the active request rather than inventing a second vocabulary |
| **AMC Active Request No.** | Code[20] | the one non-terminal request, or blank. It is both the navigation the buyer uses and **the lock**: non-blank means the order cannot be edited (§7.3). Cleared when the request closes or is cancelled |
| AMC Open Proposal Count | Integer | FlowField over `AMC Vendor Proposal` |

### `AMC Purchase Line Ext` (50101, extends `Purchase Line`)

| Field | Type | Purpose |
|---|---|---|
| AMC Origin Proposal No. | Code[20] | which proposal created or changed this line |
| AMC Origin Proposal Line No. | Integer | traceability of split and substitution lines |
| AMC Vendor Confirmed | Boolean | true once an applied proposal line covers this line |

Deliberately **no** `AMC Confirmed Date` — that is `Promised Receipt Date` (§3.1).

### `AMC Vendor Ext` (50102, extends `Vendor`)

| Field | Type | Purpose |
|---|---|---|
| AMC Collaboration Enabled | Boolean | gates request creation and every API write |
| AMC Portal Contact E-Mail | Text[80] | where access links are sent; falls back to `Vendor."E-Mail"` when blank, and request creation fails if both are empty |
| AMC Response Days | Integer | overrides `Default Response Days` from setup |
| AMC Open Proposals | Integer | FlowField, cue on the vendor card |

## 4.4 Enums

| Enum | ID | Ext. | Values |
|---|---|---|---|
| `AMC Request Status` | 50100 | yes | Draft, Sent, Awaiting Vendor, Vendor Responded, In Review, Closed, Cancelled |
| `AMC Request Line Status` | 50101 | yes | Open, Change Proposed, Partially Confirmed, Confirmed, Cancelled |
| `AMC Proposal Status` | 50102 | yes | Draft, Submitted, In Review, Changes Requested, Approved, Rejected, Applied, Apply Failed, Withdrawn, Superseded, Expired |
| `AMC Proposal Line Type` | 50103 | yes | Confirm, Change Quantity, Change Date, Split Delivery, Substitute Item, Cancel Remainder |
| `AMC Collab Entry Type` | 50104 | yes | Comment, RequestCreated, RequestSent, RequestCancelled, LinkIssued, LinkSent, LinkSendFailed, LinkOpened, LinkRejected, LinkRevoked, ProposalReceived, ProposalValidationFailed, ProposalSubmitted, ChangesRequested, ProposalApproved, ProposalRejected, ProposalApplied, PriceRecalculated, ProposalApplyFailed, OrderUnlocked, ProposalSuperseded |
| `AMC Actor Type` | 50105 | yes | Buyer, Vendor, System, Integration |
| `AMC Source Type` | 50106 | yes | Request, Proposal |
| `AMC Access Token Status` | 50107 | yes | Active, Expired, Revoked, Superseded |

One enum extension: `AMC Email Scenario Ext` (50100) adds a
`AMC Vendor Collaboration` value to the standard `Email Scenario` enum, so an
administrator can point vendor mail at a dedicated e-mail account in standard
*Email Accounts* setup instead of the app choosing a sender.

There is deliberately **no `Partially Applied` value**. A decision is made on the
whole proposal (§5.2) and apply is one transaction with a full rollback (§7.1), so
the outcomes are `Applied` and `Apply Failed` and nothing else can occur. This enum
is `Extensible = true` and therefore public: a value that ships can only be removed
as a breaking change, so shipping one that is unreachable by construction would
trade a permanent liability for nothing. If per-line decisions are ever wanted, the
value is added then, together with the semantics that make it reachable.

Three further concepts deliberately have no enum of their own, for semantic reasons
rather than economy. Proposal lines carry an `Applied` Boolean rather than a status,
for the same reason: a line has no outcome of its own while the proposal is decided
and applied as a unit. The purchase header shows
`AMC Request Status` rather than a parallel enum for the same states, because two
vocabularies for one process is how they fall out of step. Telemetry event ids are
`Label` constants in `AMC Telemetry`, next to the code that emits them.

`AMC Proposal Line Type` **must** be extensible — it carries the interface
implementation map (§6.1), so a future `Propose Price Change` can be added by
another extension without touching this app. Persisted values whose declaring
extension has been removed use the separate unknown-value handler (§6.1).

## 4.5 Codeunits

| Codeunit | ID | Responsibility |
|---|---|---|
| `AMC Request Mgt` | 50100 | create a request from a purchase order, send, cancel, close, recalculate request-line status |
| `AMC Proposal Mgt` | 50101 | submit, withdraw, supersede; creates drafts for BC-client entry |
| `AMC Proposal Validator` | 50102 | **pure validation, no side effects** — fills a `AMC Validation Result`; owns the `VCH-xxx-nnnn` error labels |
| `AMC Proposal Decision Svc` | 50103 | Approve / Reject / Request Changes, with permission checks and logging — the single entry point for a decision, whichever UI it came from (§5.2) |
| `AMC Apply Proposal Svc` | 50104 | atomic approve/apply worker, entered through `OnRun` with the Boolean result of `Codeunit.Run` captured: decision stamp → lock check → dispatch handlers → release the order → close the request → log (§7.1) |
| `AMC Collab Log` | 50105 | the only writer to `AMC Collaboration Entry`, for both events and comments |
| `AMC Telemetry` | 50106 | wrapper over `Session.LogMessage`; event ids and dimension names as labels |
| `AMC Purchase Events` | 50107 | subscribers on Purchase Header/Line that forward to `AMC Order Lock Mgt`, plus syncing collaboration status on release. It holds no rules of its own, and it never creates a request — that is a buyer action only (§5.1) |
| `AMC Business Events` | 50108 | `[ExternalBusinessEvent]` publishers for Power Automate |
| `AMC Install` | 50109 | `Subtype = Install` — setup record, default number series, upgrade tags on a fresh install |
| `AMC Upgrade` | 50110 | `Subtype = Upgrade` — dispatch plus the tag constants |
| `AMC Confirm Handler` | 50111 | implements `AMC IProposalLineHandler` |
| `AMC Change Qty Handler` | 50112 | " |
| `AMC Change Date Handler` | 50113 | " |
| `AMC Split Delivery Handler` | 50114 | " |
| `AMC Substitute Item Handler` | 50115 | " |
| `AMC Cancel Remainder Handler` | 50116 | " |
| `AMC Access Token Mgt` | 50117 | issue, hash, resolve, register an access, expire, revoke, supersede — the only writer to `AMC Vendor Access Token`; no blanket token-write elevation: lifecycle writes use internal caller permissions, while RegisterAccess uses the API page’s controlled M scope (§4.7) |
| `AMC Vendor Notification` | 50118 | resolve the recipient, mint the link, send through the standard Email module, log the outcome |
| `AMC Vendor Email Builder` | 50119 | **pure** — request + link → subject, HTML body, plain-text body; no sending, no record writes |
| `AMC Order Lock Mgt` | 50120 | owns the lock (§7.3): what it blocks, the confirm-and-cancel unlock, and the suppression window during apply |
| `AMC Idempotency Mgt` | 50121 | register a key, hash the payload, recognise a repeat and resolve it to the existing proposal (§8.5) |
| `AMC Validation Result` | 50122 | the structured accumulator a validator writes into: code, request line, sequence, text; renders to one message or to a JSON array |
| `AMC Purchase Line Builder` | 50123 | insert a purchase line next to an origin line — gap allocation, copying item, variant, location, UoM and dimensions, stamping the origin proposal |
| `AMC Token Expiry Job` | 50124 | `OnRun` for a Job Queue Entry, run daily: flip `Active` tokens past `Expires At` to `Expired` and log it. Visibility only — validation compares the date on every call anyway (§9.2) |
| `AMC Unknown Line Handler` | 50125 | implements `AMC IProposalLineHandler` for unknown persisted ordinals: Validate adds VCH-VAL-0003 to Result; Apply raises VCH-APL-0006 before writing (§6.1) |

26 codeunits, `50100–50125`. The test app takes `50130–50144` (§11.1), leaving
`50126–50129` and `50145–50149` free. Codeunit 50125 and API page 50125 do not
conflict: their object-type ID spaces are independent (§4.1).

**`AMC Order Lock Mgt`, separate from `AMC Purchase Events`.** An event subscriber
codeunit should contain dispatch and nothing else — logic inside a subscriber can
only be reached by making the platform fire the event, which means it can only be
tested by writing a purchase order. What lives here instead is the rule that keeps
the whole design honest (§7.3): what a locked order refuses, what unlocking costs,
and the window during which apply may write anyway. `AMC Purchase Events` becomes
what it should be: a handful of subscribers that each call one procedure.

**`AMC Validation Result`, instead of a `List of [Text]`.** A validation failure is
not a sentence; it is a code, a request line number, a sequence number and a text.
Flattening it into a string means every consumer parses it back out — which is
precisely why §8.4 needs a `[line s/r]` marker convention. Keeping the structure in
AL means the validator can collect *all* failures rather than stopping at the first,
the deep-insert path renders the first one into the single OData error it is allowed
(§8.3), and the JSON-payload fallback can return the whole array with no new code.
It is passed `var` between the validator and the six handlers, so a handler adds a
failure without knowing how it will be rendered.

**`AMC Purchase Line Builder`, shared by two handlers.** `AMC Split Delivery
Handler` and `AMC Substitute Item Handler` both insert new purchase lines, and
"insert a line in the free gap after the origin, copying item, variant, location,
unit of measure and dimensions, stamped with the origin proposal" is the same
non-trivial operation in both. Written twice it drifts, and a drift here corrupts a
purchase order. One builder, one set of tests for gap allocation and dimension
copying, two thin handlers on top.

**`AMC Vendor Email Builder`, separate from `AMC Vendor Notification`.** Building a
message is pure and worth asserting against — does the body contain the link, the
right number of lines, the vendor's language, no raw token in a query string.
Sending is a side effect. This is the same seam as validator against apply, and it
keeps the assertions about the e-mail out of tests that have to stand up the Email
module's test connector.

**`AMC Token Expiry Job`, and why expiry is not lazy.** A token could be treated as
expired by comparing dates at validation time, with no job at all. But then the row
still says `Active` a month after the link stopped working, and the buyer reads that
row on the request page. The state has to be true in the table, not only true in the
code path that happens to look at it. The job is scheduled by an explicit action on
the setup page rather than created by `AMC Install`: an extension should not put
entries in an administrator's job queue without being asked.

**`AMC Idempotency Mgt`, separate from `AMC Proposal Mgt`.** Retry-safety is its own
concern with its own error codes (`VCH-IDM-*`) and its own tests — same key and same
payload, same key and different payload, key released by a rollback. Keeping it out
of `AMC Proposal Mgt` leaves that codeunit describing the proposal lifecycle and
nothing else.

**Why the validator is separate:** it is called from three places — the API insert,
the buyer's approve action, and the AL tests — and it must be testable without
writing a purchase order. Folding validation into `AMC Apply Proposal Svc` is the
single most common way designs like this become untestable.

**Why all six handlers are separate:** they are the extension point (§6.1). Six
one-purpose codeunits at ~40 lines each are the point of the pattern; a `case`
statement would put six sets of purchasing rules in one object and make each of them
reachable only through the orchestrator.

## 4.6 Pages

| Page | ID | Type |
|---|---|---|
| `AMC Collaboration Setup` | 50100 | Card |
| `AMC Vendor Requests` | 50101 | List |
| `AMC Vendor Request` | 50102 | Document |
| `AMC Vendor Request Subform` | 50103 | ListPart |
| `AMC Vendor Proposals` | 50104 | List — also serves the buyer worklist, opened with a status filter from the cue |
| `AMC Vendor Proposal` | 50105 | Document |
| `AMC Vendor Proposal Subform` | 50106 | ListPart |
| `AMC Collab Timeline` | 50107 | ListPart — events and comments together, on both documents |
| `AMC Collab Activities` | 50108 | CardPart with cues |
| `AMC Vendor Access Links` | 50109 | List — every link, filterable by status and vendor. The page an administrator opens to revoke everything for one vendor after a mailbox incident |
| `AMC Vendor Access Links Part` | 50110 | ListPart on the request document — which link was sent, to whom, when it was opened, when it expires; actions *Re-send link* and *Revoke link* |

The two access-link pages are `Editable = false`, `InsertAllowed = false`,
`DeleteAllowed = false`, and neither shows `Token Hash` — there is nothing a human can do with it, and putting it
on a page is how it ends up in a screenshot. A List and a ListPart over one table is
the ordinary BC shape (the same table needs a standalone view and an embedded one);
what they must not become is two different column sets.

API pages take `50120–50125` (§8.2) — a deliberate gap after the UI pages, so the two
groups stay visibly separate — and pages use 17 of 50 IDs in total.

There is no separate "proposals to review" page. The cue on the role center opens
`AMC Vendor Proposals` filtered to `Submitted`/`In Review`, which is the same
worklist without a second page to keep in sync.

Page extensions:

| Page extension | ID | Extends | Adds |
|---|---|---|---|
| `AMC Purchase Order` | 50100 | Purchase Order (50) | actions *Send to Vendor Collaboration*, *Re-send vendor link*, *Unlock Purchase Order* (§7.3), *Vendor Requests*, *Vendor Proposals*; collaboration status fields; proposal factbox |
| `AMC Purchase Order List` | 50101 | Purchase Order List (9307) | collaboration status column, filter on orders awaiting a vendor |
| `AMC Vendor Card` | 50102 | Vendor Card (26) | collaboration fields from `AMC Vendor Ext` |
| `AMC Purchasing Agent RC` | 50103 | Purchasing Agent Role Center | `AMC Collab Activities` cue part |
| `AMC Purchase Order Subform` | 50104 | Purchase Order Subform (54) | `AMC Vendor Confirmed` and `AMC Origin Proposal No.` columns, hidden by default — the buyer looking at four lines needs to see which two came from a proposal and which proposal that was |

**Why extend the standard role center instead of shipping a new one:** buyers
already live in the Purchasing Agent role center. A dedicated role center would
force a profile switch and fragment their day. Adding a cue part is the
extension-model answer.

## 4.7 Permission sets (AL objects, not XML)

| Permission set | ID | Contents |
|---|---|---|
| `AMC Collaboration Read` | 50100 | R on all AMC tables; R on Purchase Header/Line, Vendor, Item |
| `AMC Collaboration Buyer` | 50101 | includes Read; RIM on Request/Request Line/Proposal/Proposal Line; RIM on Vendor Access Token; I on Collaboration Entry; X on `AMC Request Mgt`, `AMC Proposal Decision Svc`, `AMC Apply Proposal Svc`, `AMC Order Lock Mgt`, `AMC Access Token Mgt`, `AMC Vendor Notification`, `AMC Unknown Line Handler` |
| `AMC Collaboration Admin` | 50102 | includes Buyer; RIMD on Setup |
| `AMC Api Integration` | 50103 | R on Request/Request Line; RI on Proposal/Proposal Line; **Rm** on Vendor Access Token (direct read, indirect modify via `registerAccess` only); I on Collaboration Entry; R on Purchase Header/Line, Vendor, Item; X on `AMC Proposal Mgt`, `AMC Proposal Validator`, `AMC Validation Result`, `AMC Idempotency Mgt`, `AMC Access Token Mgt`, `AMC Unknown Line Handler` — **no D anywhere, no Setup, no access to the decision, apply, notification or order-version codeunits** |

`AMC Api Integration` is assigned to the Entra application used by the Function,
shared by all vendors. It grants direct `R` on the listed request, proposal,
token and standard tables, across all their rows in the companies where those
permissions apply. It has **no per-link or per-vendor security filter**. A
`vendorRequests` GET does not require a token or page-session proof; an S2S caller
can change/remove its OData vendor/request filter and read other authorized rows.
The token-page guard of §8.2 restricts that endpoint's lookup shape, not request
reads or the application's table-level permissions.

**The two boundaries are distinct:**

- **Browser → Function:** the Function validates the link/session, derives request
  and vendor identity, builds the BC read query itself and verifies returned
  ownership. It is the V1 enforcement point for a vendor seeing only their linked
  request. Browser routes cannot accept arbitrary BC query options, vendor ids,
  request ids or company ids to widen that scope (§13.3).
- **Function → BC:** BC authenticates the application, applies its assigned
  table/object/company permissions and validates token/request/vendor consistency
  on vendor writes. The role cannot approve, apply, delete, change setup, issue
  tokens or modify purchasing data. These restrictions protect the purchase order;
  they do not prove possession of a particular link for an S2S read.

The portal's configured `companyId` limits normal Function calls, not the BC
credential itself. Scope the BC application's role assignment to the intended
company and verify its effective permissions; a blank/all-company assignment or
additional roles can widen credential exposure. Assess compromise against **every
company and table actually authorized in BC**, not just the Function's configured
URL. Custom API projections restrict their own HTTP surface; read permissions may
also allow other accessible API/web-service surfaces over the same tables. See
[Microsoft Learn — Company scope and record-level security](https://learn.microsoft.com/en-us/dynamics365/business-central/ui-define-granular-permissions#control-access-to-specific-companies).

V1 accepts this trusted-middle-tier model. If BC itself must enforce link
possession on every read, replace the general request read APIs with controlled
AL read operations that verify an access proof and return a limited projection,
and remove the unrestricted table-read path. That stronger read boundary is not
provided by the current role.

Platform basis: [Microsoft Learn — S2S application identity and assigned permissions](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/automation-apis-using-s2s-authentication)
and [Permission set objects](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-permissionset-object).

Token modification is **indirect**: the permission set declares
`tabledata "AMC Vendor Access Token" = Rm`. Uppercase `R` permits reads;
lowercase `m` permits modification only through an object carrying the corresponding
`Permissions` property. The integration identity has no direct `M`, `I` or `D`
on this table, including through any additional assigned permission set.

The existing `vendorAccessTokens` API page (50125) is the **only object in the
integration call path** that elevates token modification:

`Permissions = tabledata "AMC Vendor Access Token" = M;`

It has `InsertAllowed = false`, `ModifyAllowed = false` and
`DeleteAllowed = false`, exposes no writable fields, and rejects ordinary modify,
insert and delete operations. Its only write entry point is the `registerAccess`
bound action, which delegates to `AMC Access Token Mgt.RegisterAccess` (§8.2).
Grant the integration role `X` on this API page and the required helper codeunits;
do not add token-modification elevation to the shared `AMC Access Token Mgt`
codeunit, the token table, other API pages or general-purpose helpers.

**Neither `m` nor the page's `M` is a field-level permission.** The action and
its helper enforce the limited update: accept the token identity only, reload and
validate the token, increment `Access Count`, stamp `Last Accessed At` and log
`LinkOpened`. They accept no caller-supplied record or values for token status,
hash, vendor, request or expiry, and invoke no lifecycle procedure. Issue, revoke,
supersede and expire remain buyer/admin or scheduled internal operations; calling
them with the integration role outside this elevated action must fail for missing
direct token-write permission. Read-only page properties protect the HTTP surface;
the `Rm` grant protects direct table modification outside the controlled object.

Permission semantics: [Microsoft Learn — Permissions property](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-permissions-property).

---

# 5. State machines

## 5.1 Vendor Request

```text
Draft --(Send)--> Sent --> Awaiting Vendor
                              |
             (proposal submitted via API)
                              v
                      Vendor Responded --(buyer opens)--> In Review
                              |                               |
                              |                   (approve + apply)
                              |                               v
                              +-------------------------->  Closed
Draft|Sent|Awaiting Vendor|Vendor Responded --(Cancel)--> Cancelled
```

`Draft` and `Send` are reached from one place only: the *Send to Vendor
Collaboration* action on the purchase order, pressed by a person who has decided
that this order should be answered by this vendor. Nothing creates a request on its
own. `AMC Purchase Events` does subscribe to release, but only to keep the
collaboration status in step — never to start a negotiation.

Releasing a purchase order is not the same statement as "ask the vendor about
this". Buyers release orders they intend to send by other means, orders for vendors
who are enabled but not relevant this time, and they re-release routinely after
edits. An automatic trigger would turn a standard, frequent, internal action into
an outbound e-mail to a third party carrying a credential, which is the last place
that should happen as a side effect.

**A purchase order has at most one request in a non-terminal status.** The
invariant is what makes `Purchase Header."AMC Active Request No."` meaningful, what
lets the vendor's link resolve to one question without ambiguity, and what keeps
`Confirmed`/`Outstanding Quantity` on the request lines from being computed against
two competing snapshots of the same order.

`AMC Request Mgt.CreateFromOrder` enforces it: it locks the purchase header, checks
for an existing request in `Draft`, `Sent`, `Awaiting Vendor`, `Vendor Responded` or
`In Review`, and refuses with `VCH-REQ-0001` naming that request. The lock matters —
the header field is a pointer, not a database constraint, and two buyers pressing
*Send* at the same moment is exactly how one gets written twice.

The refusal is deliberate rather than a silent replacement. An open request may hold
a submitted proposal that a person is still responsible for answering, and closing
it as a side effect of pressing a button on the order would discard a vendor's
answer without anyone deciding to. The two ways forward are both explicit and both
on the request itself:

- ***Re-send link*** — the same question, a new token, the previous one superseded.
  This is the answer to "they lost the e-mail" or "it went to the wrong person".
- ***Cancel*** — the question is no longer the question, usually because the order
  needs to change. It is terminal: the token is revoked, any open proposal is
  superseded with a `ProposalSuperseded` entry, and `AMC Active Request No.` is
  cleared, which **unlocks the order** (§7.3) so a fresh *Send* can capture a new
  snapshot of it. The action confirms first and names what it will supersede. The
  *Unlock Purchase Order* action on the order is the same operation reached from the
  other side.

`Closed` clears the pointer the same way, so an order whose negotiation finished
unlocks and can start another one later without anything special happening.

**A request may only be sent on an order in status `Open`.** *Send to Vendor
Collaboration* refuses a `Released` order with `VCH-REQ-0004`, naming the standard
*Reopen* action the buyer needs first. The order then stays `Open` for as long as
the request is open, and an approved proposal is what releases it (§7.1).

That mapping is the point rather than a detail. `Released` in standard Business
Central already means *this document is committed and may be acted on*, and it is
already what gates receiving, posting and invoicing. Making the vendor's
confirmation the thing that releases the order means an unconfirmed order cannot be
received against, posted or invoiced — refused by standard BC, with its own message,
with no code of ours anywhere in that path. An order nobody has confirmed is not a
document anyone should be acting on, and BC already knows it.

Creating the request stamps `AMC Active Request No.` on the order, which is what
locks it for editing until the negotiation ends (§7.3).

`Send` does three things in one transaction: it stamps the request, issues an
access token for it, and hands the e-mail to the Email module. A failure in any of
them fails all of them — a request in `Awaiting Vendor` with no way for the vendor
to reach it would be invisible from both sides. The mail *delivery* is a different
matter: the Email module owns that, retries it from its outbox, and a permanent
failure surfaces as `VCH0122` and a `LinkSendFailed` entry rather than as a rolled
back request.

The access token's own lifecycle hangs off these transitions and is described in
§9.2: `Closed` and `Cancelled` revoke it, and re-sending supersedes it.

## 5.2 Vendor Proposal

```text
  API deep insert  ------------------------+
  (validated and submitted in one call)    |
                                           v
  BC client entry --> Draft --(submit)--> Submitted --(buyer opens)--> In Review
                                                                          |
              +-------------------+-----------------+---------------------+
              v                   v                 v               v
          Approved            Rejected      Changes Requested  (request cancelled)
              |                                     |                |
        (apply service)                    (vendor submits new)  Superseded
              |                                     v
     +--------+                              Submitted
     v        v
  Applied   Apply Failed --(retry)--> Applied

Draft|Submitted --(vendor withdraws)--> Withdrawn
Submitted --(deadline passed)--> Expired
```

`Draft` is reachable only from the BC client — a buyer capturing a phoned-in
answer, or manual entry during milestone M2 before the API exists. The API path
goes straight to `Submitted` in a single transaction (§8.3), so a partially built
proposal never exists in the database.

**A decision covers the whole proposal.** There is no accept-this-line-reject-that:
`Approve` takes all of it, `Reject` takes none of it. A proposal is one business
statement — "600 on the 15th, 400 on the 20th, and B2 instead of B" — and its parts
are frequently priced and planned against each other, so a buyer who unpicks it is
agreeing to something the vendor never offered. The answer to "I accept two lines
out of three" is ***Request Changes***, which tells the vendor what is wrong and
brings back a new proposal the vendor stands behind; the previous one becomes
`Superseded` and the negotiation history shows both.

This also keeps `AMC Apply Proposal Svc` honest: what it applies is exactly what the
vendor submitted and the buyer approved, with no third version assembled in between
by a UI.

**The decision lives in this extension, not in a standard approval workflow.** That
is a reading of design principle 10.1 rather than an exception to it, because the
two mechanisms answer different questions. A standard BC approval workflow answers
*"who inside this company must sign off before this document may proceed?"* —
internal authorization, with an approver hierarchy, delegation, amount limits and a
*Requests to Approve* queue. The decision here answers *"do we accept what the
vendor offered?"* — a commercial judgement about a counterparty's statement, made by
the person who owns the order, with no hierarchy to walk and nobody to delegate to.

A technical reason reinforces it. `Approve` and apply are one operation:
`AMC Proposal Decision Svc` synchronously runs `AMC Apply Proposal Svc` with the
Boolean result of `Codeunit.Run` captured. Approval and order changes share the
worker transaction; the caller writes a failure outcome only after that transaction
has rolled back (§7.1). A buyer who approves either sees the purchase order change
or sees why it could not — while they are still looking at it. A workflow approval is
asynchronous by design: approval is granted, a response runs afterwards, and an
apply that fails then fails into a background job nobody is watching. Turning a
visible refusal into an unattended error is the wrong trade for a decision that
rewrites a commitment to a supplier.

What this is **not** is a second approval engine. There are no approval entries, no
approver hierarchy, no delegation, no amount thresholds and nothing that substitutes
for `Workflow`. There is one action, one permission set that may perform it
(`AMC Collaboration Buyer`, §4.7), and one log entry per decision. Context §16 rules
out duplicating standard approval workflows, and this stays on the right side of
that line by not attempting what they do.

Power Automate and the Power App (§14, M9) are surfaces over the same action, not
alternatives to it: a buyer approving from a phone invokes
`AMC Proposal Decision Svc` through the API, with the same permission check, the same
version check and the same log entry. Nothing outside AL decides anything.

If a company later needs "a counter-offer above X must be countersigned", that is a
genuine workflow requirement and belongs in a workflow. `AMC Proposal Decision Svc`
is the single entry point for a decision, so that integration can be built against
it as a separate extension without this one changing.

Transitions are implemented in one place per aggregate
(`AMC Request Mgt.SetStatus`, `AMC Proposal Mgt.SetStatus`) with an explicit
allowed-transition check that errors on an illegal transition. Status fields are
`Editable = false` on all pages — status only ever changes through a named
domain action.

**Why an explicit transition guard:** it turns "the process" into something a test
can assert against, and it is the cheapest defence against a future subscriber or
a Power Automate flow setting a status directly.

---

# 6. Extensibility model

## 6.1 Interface-driven line handling (the core AL pattern of this project)

```al
interface "AMC IProposalLineHandler"
{
  procedure Validate(var ProposalLine: Record "AMC Vendor Proposal Line";
                     var RequestLine: Record "AMC Vendor Request Line";
                     var Result: Codeunit "AMC Validation Result");

  procedure Apply(var ProposalLine: Record "AMC Vendor Proposal Line";
                  var PurchaseHeader: Record "Purchase Header");
}
```

```al
enum 50103 "AMC Proposal Line Type" implements "AMC IProposalLineHandler"
{
  Extensible = true;
  UnknownValueImplementation = "AMC IProposalLineHandler" = "AMC Unknown Line Handler";

  value(0; Confirm)          { Caption = 'Confirm';           Implementation = "AMC IProposalLineHandler" = "AMC Confirm Handler"; }
  value(1; "Change Quantity"){ Caption = 'Change Quantity';   Implementation = "AMC IProposalLineHandler" = "AMC Change Qty Handler"; }
  value(2; "Change Date")    { Caption = 'Change Date';       Implementation = "AMC IProposalLineHandler" = "AMC Change Date Handler"; }
  value(3; "Split Delivery") { Caption = 'Split Delivery';    Implementation = "AMC IProposalLineHandler" = "AMC Split Delivery Handler"; }
  value(4; "Substitute Item"){ Caption = 'Substitute Item';   Implementation = "AMC IProposalLineHandler" = "AMC Substitute Item Handler"; }
  value(5; "Cancel Remainder"){ Caption = 'Cancel Remainder'; Implementation = "AMC IProposalLineHandler" = "AMC Cancel Remainder Handler"; }
}
```

**Unknown persisted values (BC18+, AL runtime 7.0+).** Uninstalling an extension
can leave its numeric `Line Type` ordinal on existing proposal lines even though
the enum value and its business handler no longer exist. On conversion to
`AMC IProposalLineHandler`, `UnknownValueImplementation` selects
`AMC Unknown Line Handler` (50125), rather than allowing a technical interface
conversion error or treating the line as `Confirm`.

The handler implements both interface procedures and has no database or session
side effects:

- `Validate` adds `VCH-VAL-0003` to `Result`, including proposal/request line,
  sequence and the numeric ordinal (`ProposalLine."Line Type".AsInteger()`). It
  reports that the proposal line type is no longer available and that the buyer
  must restore the supplying extension or replace the proposal through an allowed
  domain action. It does
  not throw, so the validator still collects errors from other lines.
- `Apply` raises the controlled domain error `VCH-APL-0006` before making any
  change. The Codeunit.Run boundary of §7.1 rolls back the complete worker,
  including earlier handlers, and the caller persists `Apply Failed` with that
  error after rollback. The handler never skips the line, changes its ordinal,
  delegates to a business handler or marks it applied.

Error labels and rendering remain in `AMC Proposal Validator` (§4.5, §8.4);
the unknown handler calls its validation/error helpers so messages use the same
structured result and BC-client/API presentation rules. Grant `X` on this
handler to the buyer and integration roles that perform line validation; it needs
no elevated table-write permissions. Keep the stored ordinal and immutable
proposal intact for audit. Recovery is explicit: restore the extension and retry,
or reject/replace while the status permits it. After `Apply Failed`, if replacement
requires ending the request, cancel/unlock and send a new request (§7.3); do not add
a new status transition or edit submitted lines just to erase the unknown ordinal.

`DefaultImplementation` is a separate mechanism for **declared values without an
explicit interface mapping**; it does not handle ordinals whose declaration has
disappeared. This enum deliberately has no default business handler. Every enum
extension must supply an explicit `Implementation` for its declared line types.
The unknown handler is not a substitute for that requirement.

The declaration above requires runtime 7.0 or later. The target BC version in
§2.1 is still a placeholder and must be confirmed before implementation. If an
older target is required, do not emit the unsupported property: guard membership
against the currently installed enum values **before every interface conversion**,
return the same validation/domain failure for an absent ordinal, and preserve the
same rollback behavior. Never fall back to ordinal zero or silently ignore it.

Platform contract: [Microsoft Learn — UnknownValueImplementation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-unknownvalueimplementation-property)
and [DefaultImplementation](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-defaultimplementation-property).

The orchestrator never branches on business line type:

```al
local procedure ApplyLine(var ProposalLine: Record "AMC Vendor Proposal Line";
                          var PurchaseHeader: Record "Purchase Header")
var
  LineHandler: Interface "AMC IProposalLineHandler";
begin
  LineHandler := ProposalLine."Line Type";
  LineHandler.Apply(ProposalLine, PurchaseHeader);
end;
```

`Result` is a `AMC Validation Result` (§4.5) passed by `var`: a handler records a
failure as a code, the request line it belongs to, a sequence number and a text, and
never decides how any of that will be rendered. That is what lets the same handler
serve the deep-insert path, the JSON-payload path and a unit test that simply asserts
which codes came back.

**Why this and not a `case` statement:** a `case` over the type would put six
different sets of purchasing rules in one codeunit, make each of them untestable in
isolation, and force a modification of this app for every new proposal type.
The enum-implements-interface pattern gives one small codeunit per rule set, six
independent test codeunits (§11.1), and a genuine extension point. It is also where
the project most clearly uses modern AL rather than NAV-era procedural code.

## 6.2 Integration events (for other extensions)

Published at business boundaries only, positive and purpose-named:

```al
[IntegrationEvent(false, false)]
local procedure OnAfterCreateVendorRequest(var VendorRequest: Record "AMC Vendor Request";
                                           var PurchaseHeader: Record "Purchase Header")

[IntegrationEvent(false, false)]
local procedure OnBeforeValidateProposal(var VendorProposal: Record "AMC Vendor Proposal";
                                         var Result: Codeunit "AMC Validation Result")

[IntegrationEvent(false, false)]
local procedure OnAfterApplyProposal(var VendorProposal: Record "AMC Vendor Proposal";
                                     var PurchaseHeader: Record "Purchase Header")
```

**No `OnBefore...IsHandled` events anywhere.** Replaceable behavior is provided
through the handler interface; additive behavior through positive events. An
`IsHandled` event here would let a third party silently skip the validation that is
the entire reason this layer exists.

## 6.3 Business events (for Power Automate)

```al
[ExternalBusinessEvent('VendorProposalSubmitted', 'Vendor proposal submitted',
    'Raised when a vendor submits a proposal for a purchase order.', ...)]
procedure VendorProposalSubmitted(ProposalNo: Code[20]; VendorNo: Code[20];
                                  PurchaseOrderNo: Code[20]; RequestNo: Code[20])
begin
end;
```

Events published: `VendorProposalSubmitted`, `VendorProposalApproved`,
`VendorProposalRejected`, `VendorRequestOverdue`, `VendorAccessRejected`.

`VendorAccessRejected` carries the request and the reason, never the token or its
hash. It exists because a vendor cannot ask for a new link themselves (§9.5), so
somebody has to notice that they tried.

> Verify the exact `[ExternalBusinessEvent]` attribute signature against your AL
> runtime before coding — it has changed between releases.

**Why business events instead of a webhook subscription or a polling flow:**
polling (`When a record is modified` on an API page) costs a flow run per interval
forever, has latency, and misses fast transitions. Business events are the
supported, versioned, push-based contract designed exactly for Power Automate, and
they keep the notification concern out of AL. The alternative — calling an HTTP
endpoint from AL directly — would put the outbound retry/timeout problem inside the
ERP transaction, which is the anti-pattern this whole architecture avoids.

---

# 7. Applying a proposal

## 7.1 Orchestration

```text
AMC Apply Proposal Svc.OnRun(DecisionContext) — atomic approve/apply worker
 0. Re-read and lock the proposal; re-check permission and allowed decision/retry
    transition; set Approved, stamp decision user/time, log ProposalApproved
 1. Check Proposal.Status = Approved                    else VCH-APL-0001
 2. Get Purchase Header (SetLoadFields)                 else VCH-APL-0002
 3. AMC Order Lock Mgt.AssertLockedBy(Proposal, Header) else VCH-APL-0003
 4. AMC Order Lock Mgt.Suppress()                       our own writes must pass
                                                        through the lock
 5. For each proposal line in Sequence No. order:
       LineHandler := Line."Line Type";
       LineHandler.Apply(Line, Header);
       Line.Applied := true;
       Collab Log: ProposalApplied (old value / new value per field)
       Collab Log: PriceRecalculated if unit cost or discount moved (§7.2)
 6. Recalculate request line Confirmed / Outstanding Quantity and status
 7. Release Purchase Document.Run(Header)  -> Released: the vendor's answer is
                                              what commits this order
 8. Close the request, clear AMC Active Request No. -> the order unlocks;
    revoke the request token; supersede every other open proposal on this order
 9. Proposal.Status := Applied
10. Business event VendorProposalApproved
```

The two outcomes are `Applied` and `Apply Failed`. There is no partial outcome to
represent: the decision covered the whole proposal (§5.2) and the transaction covers
the whole apply, so either every line reached the purchase order or none did.

**The transaction boundary is the captured Boolean result of `Codeunit.Run`.**
`AMC Apply Proposal Svc` has `TableNo = "AMC Vendor Proposal"`; its `OnRun`
receives a temporary proposal record carrying the proposal identity and decision
context, then loads the persisted records afresh. Steps 0–10 run in **one worker
transaction**: approval status/stamp/log, purchase header and lines, line-applied
flags, request recalculation/closure, token revocation, superseding other proposals
and all success audit entries commit together on a successful Run. Any error rolls
back all those writes before Run returns `false`. A `[TryFunction]` wrapper must
never be used as the rollback boundary for this write path.

`AMC Proposal Decision Svc` owns the call and the outcome handling:

1. Enter with **no open write transaction**. Before Run, only read/check permissions
   and prepare temporary context; do not persist `Approved`, decision stamps or
   logs. BC page and buyer API entry points must finish any unrelated page-save or
   request writes at their own explicit boundary before invoking this service.
   Never commit an approval separately just to make Run callable.
2. Save the previous suppression state (and any other session flags changed by
   apply), call `ClearLastError()`, then capture the result of
   `Codeunit.Run(Codeunit::"AMC Apply Proposal Svc", DecisionContext)`.
3. On `false`, immediately copy the error details to local variables before another
   call can overwrite the session error buffer. Restore the saved session flags
   explicitly on **both** success and failure; database rollback does not restore
   session state. Reload persisted records rather than reusing worker record buffers.
4. On success, the worker has already committed `Applied` and the complete order
   change. Emit `VCH0220` with duration and line count after Run returns `true`.
5. On failure, the order is untouched, still locked and `Open`; the request and token
   keep their pre-apply state, and no approval stamp or success audit entry remains.
   In a **new transaction**, write `Status = Apply Failed`, `Last Error Code`,
   `Last Error Message` and `ProposalApplyFailed`; emit `VCH0221`. Complete this
   transaction normally and return the failure outcome to the UI. Do not raise an
   uncaught `Error` afterwards that would erase the failure record. A retry enters
   the same worker boundary with the allowed `Apply Failed` transition re-checked.

**No intermediate commits are allowed inside the worker**, its handlers, standard
release path or subscribers. Invoke the standard release routine without capturing
a nested Run result that would introduce an implicit commit. Where the target
runtime supports it (runtime 6.0+), use `[CommitBehavior(CommitBehavior::Error)]`
on the worker entry method to reject explicit `Commit()` calls in its call tree.
This attribute does not block implicit commits from Boolean `Codeunit.Run` calls;
those nested calls must be excluded by design and review.

Platform semantics: [Microsoft Learn — Codeunit.Run](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/codeunit/codeunit-run-method),
[Try methods](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-handling-errors-using-try-methods)
and [CommitBehavior](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/attributes/devenv-commitbehavior-attribute).

## 7.2 Per-handler rules

| Line type | Effect on Purchase Line | Validation |
|---|---|---|
| **Confirm** | `Promised Receipt Date` := requested date; `AMC Vendor Confirmed` := true | quantity must equal requested outstanding |
| **Change Quantity** | `Validate(Quantity, proposed)` | proposed ≥ `Quantity Received`; proposed ≥ `Qty. Rcd. Not Invoiced`; increase only if `Allow Quantity Increase`; > 0 |
| **Change Date** | `Validate("Promised Receipt Date", proposed)` | date ≥ WORKDATE; not more than *N* days beyond requested without a reason code |
| **Split Delivery** | original line `Quantity` := first split; the remaining splits are inserted through `AMC Purchase Line Builder` — **inside the free gap directly after the origin line** (midpoint of the gap, so splits stay adjacent to what they came from), copying item/variant/location/UoM/dimensions, each with its own `Promised Receipt Date` and stamped `AMC Origin Proposal No./Line No.` | Σ splits ≤ requested quantity (= requested unless a Cancel Remainder line is present); split count ≤ `Max Splits per Line`; no split before WORKDATE; the gap after the origin line must be wide enough for the number of splits, otherwise error `VCH-APL-0004` |
| **Substitute Item** | `AMC Purchase Line Builder` inserts a new Purchase Line for the substitute, overriding item and variant; the original is reduced or cancelled | `Allow Item Substitution` = true; the pair must exist in standard `Item Substitution`; substitute must be non-blocked and purchasable |
| **Cancel Remainder** | `Validate(Quantity, Quantity Received)` | line must have `Quantity Received` < `Quantity`; requires a reason code |

**Every write goes through `Validate()`, never a direct field assignment.** Standard
BC field validation — dimensions, prices, planning, blocked items, unit of measure —
therefore runs exactly as it does for a buyer typing the same change. That rule is
what `AMC Purchase Line Builder` encapsulates for the two handlers that create
lines: the field order of a correct insert — type, then `No.`, then variant,
location, UoM, quantity, dates — is easy to get subtly wrong, and getting it wrong
produces a line that looks right and prices wrong.

**The price consequence is recorded.** The extension never carries a price forward
by hand, never pins one and never suppresses the recalculation, so four of the six
line types can move a price, and only the first is obvious:

| Line type | Why the price can move |
|---|---|
| Substitute Item | a different item has a different price-list entry |
| Change Quantity | the new quantity may fall on the other side of a quantity break or line discount |
| Split Delivery | 1000 split into 600 + 400 can drop **both** lines below a break that 1000 cleared, so the unit price rises on lines nobody asked to reprice |
| Cancel Remainder | the same effect, reached from the other direction |

Whenever `Direct Unit Cost` or `Line Discount %` differs after a handler has run,
`AMC Apply Proposal Svc` writes a `PriceRecalculated` entry with the old value, the
new value and the purchase line it happened on. It is its own entry type rather than
one more `ProposalApplied` field row because it is the one change in the flow that
**nobody asked for**: the vendor proposed a quantity and a date, the buyer approved a
quantity and a date, and the price moved as a consequence. A buyer reviewing what an
approval actually did — or an auditor asking why a line costs what it costs — should
be able to filter for exactly that, and the `Entry Type, Date Time` key (§4.2) makes
it a one-filter question.

The entry is business history, so it goes to `AMC Collaboration Entry` and not to
Application Insights; §10 draws that line.

Apply is never blocked by a price change and there is no tolerance threshold.
Standard BC is the authority on what an item costs, and this layer's job is to make
the consequence visible rather than to second-guess it.

**Why insert new lines instead of a custom "delivery schedule" sub-table:**
BC's own model for "same item, two dates" is two purchase lines. A custom schedule
table would be invisible to receipts, planning, availability and reporting — a
textbook violation of principle 10.1.

## 7.3 Locking the purchase order

> *What happens if the purchase order changes after the vendor submits a proposal?*

It cannot. **An open request locks its purchase order for editing**, and that
invariant is the whole answer.

`Purchase Header."AMC Active Request No."` is the lock: non-blank means locked. It
is already the field that says which request is open (§4.3), so the lock introduces
no state of its own. `AMC Order Lock Mgt` owns the rule; `AMC Purchase Events` only
subscribes and forwards.

| Blocked while locked | Why |
|---|---|
| Modify, insert and delete on `Purchase Line` | this is the data the vendor is answering about |
| Modify on `Purchase Header` | vendor, currency and order date change what was asked |
| Delete of the order | there is an open negotiation attached to it |
| `Release` | releasing is what says "this is committed", and that is the vendor's answer to give, not the buyer's to assume |

Nothing else needs blocking, because there is nothing left to block. A request can
only be sent on an order in status `Open`, and the order stays `Open` until an
approved proposal releases it (§5.1). Receiving, posting and invoicing are therefore
refused by standard Business Central with its own message, without a subscriber of
ours anywhere in that path — which is the reason the confirmation is mapped onto
`Released` rather than onto a status of our own.

Two things unlock the order, and there is no third:

1. **An approved proposal is applied.** `AMC Apply Proposal Svc` closes the request
   and clears the pointer as its last step (§7.1), so the order is free the moment
   the negotiation has produced its answer.
2. **The buyer unlocks it deliberately**, through *Unlock Purchase Order* on the
   order.

**Unlocking is cancelling.** The action confirms first, and the confirmation says
what is actually about to happen rather than asking an abstract question:

```text
Purchase order PO-10482 was sent to Contoso Components on 07-09-2026 and has not
been answered yet.

Unlocking cancels the request: the vendor's link stops working and any proposal
they have already submitted is superseded.

Continue?
```

On yes it calls `AMC Request Mgt.Cancel`, which revokes the access token, supersedes
any open proposal, writes an `OrderUnlocked` entry naming the user, emits `VCH0230`,
and clears `AMC Active Request No.`. There is no state in which the order is
editable *and* a request is still waiting for an answer — which is precisely the
state a version counter would otherwise have to detect after the fact.

**Why a lock and not a version counter.** The alternative is to leave the order
editable and detect staleness at approval time: an integer on the header, bumped by
subscribers whenever a collaboration-relevant field changes, snapshotted onto the
request, carried through the API on every proposal, and compared before applying.
That works, but it puts the failure at the worst possible moment. The vendor has
already spent the effort answering, the buyer has already decided to approve, and
only then does the system say no — and the only remedy left is to start the
negotiation again.

The lock moves the same decision to the front, where a person is present and it is
cheap: you cannot edit this order, and if you must, you are ending the negotiation.
It also removes a field from the purchase header, a field from the request, a field
from the proposal, a field from the API contract, an error code, a business event,
and the entire question of which field changes count as collaboration-relevant —
which was the fiddliest rule in the design and the one most likely to be quietly
wrong.

**The cost, stated plainly.** An order is unavailable for editing while a vendor is
answering, which can be days. A buyer who needs to correct something pays for it by
cancelling and re-sending. That is a real operational cost, and it is the reason the
unlock action exists at all: the answer to "I need to change this now" has to be one
click and a warning, not a support call.

**During apply.** `AMC Apply Proposal Svc` writes to the order it locked, so
`AMC Order Lock Mgt.Suppress` opens a window for the duration of the transaction and
`AMC Proposal Decision Svc` restores the saved suppression state explicitly after
`Codeunit.Run` on both success and failure (§7.1). Suppression is session state that
a database rollback does not undo; restore the previous value rather than blindly
clearing it. The same rule applies to every session flag changed during apply.

---

# 8. API contract

## 8.1 Shape

Custom **API pages** (`PageType = API`), not OData V4 web services on standard pages.

```text
https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{environment}
      /api/adrianoth/collaboration/v1.0
      /companies({companyId})/{entity}
```

`APIPublisher = 'adrianoth'`, `APIGroup = 'collaboration'`, `APIVersion = 'v1.0'`.

**`{companyId}` is deployment configuration, not a parameter.** The vendor-facing
surface serves one Business Central company, and its id is an app setting of the
Function (§13.3). Nothing downstream can influence it: not the link, not the page,
not a request body. That is a security property as much as a scoping one — a token
id or a token hash from one company simply does not resolve when the lookup is
pinned to another. The browser cannot choose a company through the Function.
This is not a company restriction on the S2S credential: its BC assignments must
be scoped separately (§4.7).

A second company would get its own Function configuration and its own link host,
which is the cheap answer and the one that keeps this property. Carrying a company
in the link would mean resolving a token before knowing which company to ask, and
Business Central has no cross-company lookup to answer that in one call — so
multi-company is a deployment question here, not an API-contract question.

Common page properties: `PageType = API`, `DelayedInsert = true`,
`ODataKeyFields = SystemId`, `Extensible = false`, explicit
`EntityName`/`EntitySetName`, camelCase field names, `id` = `SystemId`,
`lastModifiedDateTime` = `SystemModifiedAt`.

**Why custom API pages and not exposing standard pages as web services:**
a published standard page is a leaky contract — it exposes every field including
ones added by future extensions, it changes shape when Microsoft changes the page,
and it lets an external caller write straight into `Purchase Line`. An API page is
an explicit, versioned projection with `InsertAllowed`/`ModifyAllowed`/
`DeleteAllowed` set per entity. **Why not a pure command API — one codeunit action
per operation:** the read side genuinely needs OData. The Function must resolve a
token by hash, read one request with its lines expanded, page through results and
rely on ETags; a bespoke command endpoint would force all of that to be hand-built
on both sides. The write side is a different matter — it *is* command-shaped, and §8.3
handles it with a single atomic insert rather than a CRUD sequence, keeping the
OData surface while behaving like a command.

## 8.2 Entities

| Entity set | Page | Read | Create | Update | Delete |
|---|---|---|---|---|---|
| `vendorRequests` | 50120 | ✓ | | | |
| `vendorRequestLines` | 50121 | ✓ | | | |
| `vendorProposals` | 50122 | ✓ | ✓ (deep insert, submits immediately) | | |
| `vendorProposalLines` | 50123 | ✓ | only nested inside a `vendorProposals` insert | | |
| `collaborationComments` | 50124 | ✓ | ✓ | | |
| `vendorAccessTokens` | 50125 | ✓ (one exact hash or resolved token id; §8.2) | | | |

`vendorProposalLines` is exposed on page 50122 as a `part`, which is what makes the
deep insert in §8.3 possible; it is also addressable directly for reads
(`GET .../vendorProposals({id})/vendorProposalLines`).

`vendorAccessTokens` is the Function's only lookup path from a link to a request.
Page 50125 declares read-only API fields `id`, `tokenHash`, `requestNumber`,
`vendorNumber`, `status` and `expiresAt`. In particular,
`field(tokenHash; Rec."Token Hash")` is a real field in the page layout, with
`Editable = false`: `tokenHash` is an `Edm.String` property in `$metadata`
and is therefore addressable in an OData `$filter`. A table field absent from the
API layout is not a substitute for this property. The raw token is never an API
property; page writes remain restricted to `registerAccess` (§4.7).

**Lookup contract (Function → BC only):**

- The Function computes SHA-256 as exactly 64 uppercase hexadecimal characters
  (`0–9`, `A–F`) and sends `$filter=tokenHash eq '<64-character hash>'`.
  Construct and URL-encode the query through the HTTP client's query builder.
- It always requests
  `$select=id,requestNumber,vendorNumber,status,expiresAt`. The hash is filterable
  even though it is omitted from this response projection. `$select` is a client
  projection, not a security boundary: an authenticated S2S caller omitting it can
  receive `tokenHash` for the matched record.
- Before reading rows, the page validates its effective AL filters. Accept only a
  single exact hash of that format; reject missing, malformed, wildcard, range,
  inequality and multi-value hash filters. Check the complete filter value, not
  merely whether `GetFilter("Token Hash")` is non-empty. Apply the validated hash
  again with `SetRange` in a server-controlled filter group so additional client
  options cannot broaden the lookup. The unique `Token Hash` key means the result
  contains zero or one row; `$top` is not the restriction mechanism.
- The existing keyed `registerAccess` action uses the previously resolved
  `SystemId`. The guard also accepts a single exact `SystemId` scope for keyed
  access, without requiring the hash to be resent. Reject unscoped collection reads
  and any filter that could match several ids; a known id is not permission to list
  tokens. If both id and hash are supplied, keep both constraints. The action reloads
  and validates the bound token before writing (§4.7).
- Zero rows means an unknown link; more than one row is a contract violation and
  fails closed. For one row, the Function checks status/expiry before creating a
  session. It never passes `tokenHash` to the browser, JWT claims, business events
  or logs. Suppress/redact the BC lookup query string and response bodies in Function
  HTTP diagnostics and dependency telemetry; they can contain a sensitive hash.

This guarded projection is the V1 contract for the trusted S2S caller; it does not
make hashes generally unreadable to that caller. The UI token pages still omit
`Token Hash` (§4.6), and browser responses contain only the portal DTO.

Contract basis: [Microsoft Learn — Custom API pages](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-develop-custom-api)
and [API/OData filters](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-connect-apps-filtering).

The page's one bound action stamps an access:

```http
POST .../vendorAccessTokens({tokenId})/Microsoft.NAV.registerAccess
```

which calls `AMC Access Token Mgt.RegisterAccess` under page 50125's
`Permissions = tabledata "AMC Vendor Access Token" = M`. The integration role
supplies indirect `m` (§4.7); ordinary POST/PATCH/DELETE remain disabled. The action
accepts only the bound token identity, reloads and validates the token, increments
`Access Count`, stamps `Last Accessed At` and writes a `LinkOpened` entry to the
timeline in one transaction. It returns no data and leaves status, hash, request,
vendor and expiry unchanged. No lifecycle method runs under this elevated scope.

Two properties of this table carry most of the security model:

- **Requests are read-only over the API by construction** — the vendor answers
  work, it never creates work.
- **A proposal is write-once.** There is no update and no delete over the API.
  A vendor who changes their mind submits a new proposal, which supersedes the
  previous one (§5.2). `OnModifyRecord` and `OnDeleteRecord` on the API page error
  unconditionally rather than relying only on `ModifyAllowed`/`DeleteAllowed`, so
  the rule holds no matter how the record is reached.

The only mutation a vendor can perform after submitting is `withdraw`, a bound
action that moves the proposal to `Withdrawn` without changing any of its data:

```http
POST .../vendorProposals({proposalId})/Microsoft.NAV.withdraw
```

It is refused once the buyer has made a decision (`VCH-STA-0001`).

## 8.3 Examples

**Resolve an access link**

The Function's first call — everything else in this section depends on it. The
64-character hash below is illustrative; the actual value is computed from the
presented token. The HTTP client URL-encodes the query shown here for readability:

```http
GET .../vendorAccessTokens
    ?$filter=tokenHash eq '9C4E00000000000000000000000000000000000000000000000000000000A17B'
    &$select=id,requestNumber,vendorNumber,status,expiresAt
```

```jsonc
{ "value": [ { "id": "b1f0c3d2-...-0e13", "requestNumber": "VCR-000148",
               "vendorNumber": "V10000", "status": "Active",
               "expiresAt": "2026-09-24T23:59:00Z" } ] }
```

An empty result and an expired or revoked token are the same outcome for the
vendor: the page shows that the link no longer works and who to contact.

**Trusted S2S example — list open requests for a vendor**

This BC endpoint accepts the shared application credential without proving link
possession. Its vendor filter selects rows; it is not authorization. The portal
exposes no list-all-requests route. For `/api/request`, the Function constructs an
exact request-number and vendor-number filter from validated session claims and
checks the returned request and expanded lines before returning the portal DTO.

```http
GET /api/adrianoth/collaboration/v1.0/companies({id})/vendorRequests
    ?$filter=vendorNumber eq 'V10000' and status eq 'Awaiting Vendor'
    &$expand=vendorRequestLines
    &$top=20
```

```jsonc
{
  "@odata.context": "...",
  "value": [
    {
      "@odata.etag": "W/\"JzQ0O...\"",
      "id": "b2b6c8a1-...-9f21",
      "number": "VCR-000148",
      "vendorNumber": "V10000",
      "purchaseOrderNumber": "PO-10482",
      "status": "Awaiting Vendor",
      "sentDateTime": "2026-09-07T09:12:44Z",
      "responseDeadline": "2026-09-10",
      "currencyCode": "EUR",
      "languageCode": "ENU",
      "lastModifiedDateTime": "2026-09-07T09:12:44Z",
      "vendorRequestLines": [
        {
          "id": "3f0c...-11ae",
          "lineNumber": 10000,
          "itemNumber": "ITEM-A",
          "description": "Component A",
          "unitOfMeasureCode": "PCS",
          "requestedQuantity": 1000,
          "requestedDeliveryDate": "2026-09-15",
          "confirmedQuantity": 0,
          "outstandingQuantity": 1000,
          "status": "Open"
        }
      ]
    }
  ],
  "@odata.nextLink": "...$skiptoken=..."
}
```

**Submit a proposal — one atomic call (deep insert)**

Item A split 600 + 400, Item B substituted with ITEM-B2:

```http
POST .../vendorProposals
Content-Type: application/json

{
  "requestNumber": "VCR-000148",
  "vendorNumber": "V10000",
  "accessTokenId": "b1f0c3d2-9a4e-4c2a-8f61-27d9a5b40e13",
  "idempotencyKey": "b7f0a2e4-vch-2026-09-07-0001",
  "submittedBy": "anna.k@contoso-components.com",
  "externalReference": "CC-ACK-55821",
  "vendorProposalLines": [
    { "requestLineNumber": 10000, "lineType": "Split Delivery", "sequenceNumber": 1,
      "proposedQuantity": 600, "proposedDeliveryDate": "2026-09-15",
      "reasonCode": "CAPACITY", "reasonDescription": "Production capacity limitation" },

    { "requestLineNumber": 10000, "lineType": "Split Delivery", "sequenceNumber": 2,
      "proposedQuantity": 400, "proposedDeliveryDate": "2026-09-20",
      "reasonCode": "CAPACITY", "reasonDescription": "Production capacity limitation" },

    { "requestLineNumber": 20000, "lineType": "Substitute Item", "sequenceNumber": 1,
      "proposedItemNumber": "ITEM-B2", "proposedQuantity": 500,
      "proposedDeliveryDate": "2026-09-18",
      "reasonCode": "UNAVAIL", "reasonDescription": "Original item temporarily unavailable" }
  ]
}
```

`requestNumber`, `vendorNumber` and `accessTokenId` are attached by the Function
from the page session — never copied from what the browser sent. That is what
allows the AL side to treat them as claims rather than as input.

`201 Created` returns the full proposal with `"status": "Submitted"`, its `number`,
its `id`, and the created lines.

What happens inside that one call, in one transaction:

```text
AMC Api Vendor Proposal.OnInsertRecord
  1. Setup Enabled? Vendor Collaboration Enabled?      else VCH-AUT-0001 / 0002
  2. AMC Access Token Mgt.Assert(accessTokenId,
       requestNumber, vendorNumber)                    else VCH-AUT-0003 / 0004
  3. AMC Idempotency Mgt.Register(vendor, key, payloadHash)
                                                       duplicate -> VCH-IDM-0000/0001
  4. Request exists, belongs to this vendor, is open?  else VCH-VAL-0001
  5. insert header + all nested lines
  6. AMC Proposal Validator.Validate(proposal, Result) Result.HasErrors ->
                                                       Error(Result.AsErrorText)
                                                       -> full rollback
  7. Status := Submitted, Submitted Date Time := now
  8. log ProposalReceived + ProposalSubmitted, telemetry VCH0201/VCH0203
  9. business event VendorProposalSubmitted
```

Step 2 enforces consistency on the BC write path: BC checks that the supplied
token id is active and belongs to the request/vendor. It does not require the raw
link and does not authenticate the browser independently. The Function proves
browser link/session access; BC validates the submitted record pairing. This
write check does not authorize or scope the general S2S request GETs (§4.7).

Any failure in steps 1–6 rolls back the whole insert. There is no half-written
proposal, and no `Draft` row left behind for someone to clean up.

**Why one atomic call and not create-draft-then-add-lines-then-submit:**

- **Validation here is cross-line.** `Σ splits ≤ outstanding quantity` and
  `split count ≤ Max Splits per Line` are statements about the whole answer. If
  lines arrive one POST at a time, each individual insert passes trivially and the
  real validation only runs at the end — the caller gets N calls of false
  confidence before the rejection.
- **Idempotency then covers exactly one operation.** A key protecting only the
  header POST leaves a retry after a mid-sequence crash with a partially populated
  proposal and no defined resume semantics.
- **A half-finished answer is client state, not ERP state.** "Save and continue
  later" belongs in the vendor's own browser (§13.2). Applying the context
  document's ownership test — *which system owns this record?* — an unsubmitted
  vendor draft is not owned by Business Central.

`Draft` remains in the status enum because proposals can also be entered manually
in the BC client (milestone M2, before the API exists), and because a buyer may
capture a phoned-in answer. **The API path never produces a `Draft`.**

> Verify deep insert against your AL runtime before building the Function's
> client:
> the child API page must be exposed as a `part` on the parent API page. If it
> proves too limiting — the main constraint is that a deep insert returns **one**
> OData error, so per-line failures must be encoded in the message rather than
> returned as a list — the fallback is a bound action taking the whole proposal as
> a JSON payload (`POST .../vendorProposals/Microsoft.NAV.submitProposal`), which
> keeps the same atomicity and lets you return a structured error array. Record
> whichever you land on in ADR-004.

**Comment**

```http
POST .../collaborationComments
{ "sourceType": "Proposal", "sourceNumber": "VCP-000091",
  "accessTokenId": "b1f0c3d2-9a4e-4c2a-8f61-27d9a5b40e13",
  "authorName": "anna.k@contoso-components.com",
  "comment": "We can pull 400 pcs forward to 2026-09-18 if you accept partial invoicing." }
```

`visibleToVendor` is not writable over the API — it is forced to `true` for
vendor-authored comments.

## 8.4 Error contract

BC returns OData errors and you cannot fully control `error.code`. Therefore every
`Error()` that **can cross the API** starts with a stable code:

```jsonc
{
  "error": {
    "code": "Application_DialogException",
    "message": "VCH-VAL-0012: Proposed quantity 1200 exceeds outstanding quantity 1000 on request line 10000. CorrelationId: 8f2c...  "
  }
}
```

The Function parses the `VCH-xxx-nnnn` prefix, never the message text.

Because a deep insert returns **one** OData error for the whole request, every
line-level failure must name its line in the message. The convention is
`VCH-xxx-nnnn [line <sequence>/<requestLineNumber>]: <text>`, so the page can
highlight the offending row in its editor:

```text
VCH-VAL-0030 [line 1/20000]: Item ITEM-B2 is not a registered substitute for ITEM-B.
```

**Validation does not stop at the first failure.** `AMC Validation Result` (§4.5)
collects every one of them, so a vendor who got three things wrong can be told about
three things. What limits this is the transport, not the validator: a deep insert
may return one OData error, so that path renders the first failure and puts the
total count and the full code list into telemetry (`VCH0202`). That number is the
evidence for or against switching — if vendors routinely trip several rules at
once, the JSON-payload action at the end of §8.3 stops being a fallback and becomes
the right call, and no validator or handler code changes when it does.

| Code | Meaning | HTTP |
|---|---|---|
| `VCH-REQ-0001` | The order already has an active request | — BC client, code not shown |
| `VCH-REQ-0002` | Link validity is shorter than the vendor's response days | — BC client, code not shown |
| `VCH-REQ-0003` | The vendor has no address to send the link to | — BC client, code not shown |
| `VCH-REQ-0004` | The order is Released; it must be Open to be sent | — BC client, code not shown |
| `VCH-AUT-0001` | Collaboration disabled in setup | 400 |
| `VCH-AUT-0002` | Vendor not enabled for collaboration | 400 |
| `VCH-AUT-0003` | Access token expired, revoked or superseded | 400 |
| `VCH-AUT-0004` | Access token does not belong to this request or vendor | 400 |
| `VCH-VAL-0001` | Request not found / not open | 400 |
| `VCH-VAL-0002` | Request line not found | 400 |
| `VCH-VAL-0003` | Persisted proposal line type is no longer available (unknown enum ordinal) | 400 |
| `VCH-VAL-0010` | Quantity must be positive | 400 |
| `VCH-VAL-0012` | Proposed quantity exceeds outstanding | 400 |
| `VCH-VAL-0020` | Delivery date in the past | 400 |
| `VCH-VAL-0030` | Item substitution not allowed / not registered | 400 |
| `VCH-VAL-0031` | Split count exceeds `Max Splits per Line` | 400 |
| `VCH-VAL-0040` | Reason code required | 400 |
| `VCH-IDM-0001` | Idempotency key already used with a different payload | 409 |
| `VCH-STA-0001` | Illegal status transition | 400 |
| `VCH-APL-0001..4` | Apply-time failures (see §7.1, §7.2) | 500 |
| `VCH-APL-0006` | Unknown persisted line type reached apply; restore its extension or replace the proposal (§6.1) | — internal apply failure, shown in the BC client |

**Errors raised in the BC client show no code.** The `VCH-REQ-*` rows above name a
condition for this document, for telemetry and for tests — not for the buyer, who
gets a sentence naming the request, the vendor or the two numbers that disagree.
Nothing parses those messages, so a prefix would achieve nothing except putting an
internal identifier in front of a person, which is the same rule as §1's on
captions. The prefix exists only where a machine reads it: on the way out through
the API.

A machine-readable copy of this table lives in `docs/api/error-codes.md` and is
generated from the labels in `AMC Proposal Validator`, so the codes cannot drift.

The vendor never sees a `AMC-` code. The Function maps every one of them to a small
vendor-facing set, because a message written for a developer is not a message
written for someone answering a purchase order:

| Function code | HTTP | Shown as | Mapped from |
|---|---|---|---|
| `LINK-0001` | 401 | "This link is not valid." | no token matches the hash |
| `LINK-0002` | 401 | "This link has expired. Ask your contact to send a new one." | expired / revoked / superseded token, `VCH-AUT-0003` |
| `LINK-0003` | 403 | "This link is not valid for this order." | session/request mismatch, `VCH-AUT-0004` |
| `LINK-0004` | 409 | "This order is no longer open for changes." | `VCH-VAL-0001` |
| `FORM-0001` | 400 | the validation message, against the row it belongs to | any `VCH-VAL-*`, using the `[line s/r]` marker |
| `BUSY-0001` | 429 | "Too many attempts. Try again shortly." | rate limit, or a BC `429` |

Anything unmapped becomes a generic failure with a correlation id the vendor can
quote, and the original code goes to Application Insights, not to the page.

## 8.5 Idempotency

**Constraint that drives the design: a BC API page cannot read HTTP request
headers.** The usual `Idempotency-Key` header is therefore not available. The key
is a **field in the payload** (`idempotencyKey`), backed by a unique key on
`Vendor No. + Idempotency Key`.

Flow on `POST /vendorProposals`:

1. `OnInsertRecord` calls `AMC Idempotency Mgt.Register(vendorNo, key, payloadHash)`,
   which writes the key onto the proposal and lets the unique index reject a repeat.
2. Key unused → register, insert header + lines, validate, submit, return `201`.
3. Key used, same payload hash → **no insert**; error
   `VCH-IDM-0000: duplicate request, existing proposal id = {guid}, number = {no}`.
   The Function treats this specific code as success and reuses the returned id.
4. Key used, different payload hash → `VCH-IDM-0001` (a genuine client bug).

The single-call design of §8.3 is what makes this honest: **the idempotency key
protects exactly one atomic operation.** One key, one HTTP call, one transaction,
one proposal — the retry semantics are total. Had the proposal been assembled over
several calls, the key would have covered only the header and a crash mid-sequence
would leave a partial proposal with no defined resume behavior.

There is no separate idempotency ledger to clean up: the key lives on the proposal
and shares its lifetime. Keys of rejected submits disappear with the rollback,
which is what makes a rejected proposal retryable under the same key.

**Why idempotency at all:** the Function retries on `429`/`504`/timeouts, the
vendor retries by pressing the button again, and a timeout tells neither of them
whether BC committed. Without a key, a retried "we can only deliver 600" becomes
two competing proposals in the buyer's queue.

## 8.6 Paging, filtering, throttling

- The Function always pages via `@odata.nextLink`; it never assumes a full result
  set.
- Server-side `$filter` only — no client-side filtering of a full download.
- `$select` on list views to reduce payload.
- BC throttles per environment: on `429` the Function honors `Retry-After`; on
  `5xx`/timeout it retries with exponential backoff + jitter, **max 3 attempts**,
  and every retry carries the same `idempotencyKey`. A vendor waiting on a page
  sees `BUSY-0001`, not a stack of retries.
- Long-running reads are avoided by keeping API pages free of FlowFields that
  aggregate across large tables.

## 8.7 Versioning

`v1.0` is frozen once the Function ships against it. The vendor page never sees
this contract — it consumes the Function's own `vendor-api-v1.yaml`, which is what
lets the two evolve independently. Rules:

- Additive only within a version (new optional fields are allowed).
- A removed field, a renamed field, a narrowed type or a changed enum value ⇒
  new `APIVersion = 'v2.0'` page, both versions served in parallel for one release.
- Enum values are transmitted as strings; adding a value is additive, so the
  Function must ignore unknown values rather than fail.
- The contract is documented as an OpenAPI file in `docs/api/collaboration-v1.yaml`
  and kept in the repo — it is what the Function's BC client is generated from.
  `docs/api/vendor-api-v1.yaml` does the same for the page's client.

---

# 9. Security

## 9.1 The chain of trust

There are three hops between a vendor and a purchase order, and each uses a
different kind of credential:

```text
VENDOR              STATIC WEB APP        AZURE FUNCTION       BUSINESS CENTRAL
  |                       |                     |                     |
  | possession of a link  |                     |                     |
  |---------------------->|                     |                     |
  |                       | POST /api/session   |                     |
  |                       |-------------------->| SHA-256 lookup      |
  |                       |                     |-------------------->|
  |                       |<-- page session ----|<-- token record ----|
  |                       |                     |                     |
  | page session (30 min, one request in its claims)                  |
  |------------------------------------------->| OAuth 2.0 client    |
  |                                             | credentials (Entra) |
  |                                             |-------------------->|
```

| Hop | Credential | Proves | Lives |
|---|---|---|---|
| Vendor → page | the access link | possession | in the vendor's mailbox, until it expires or is revoked |
| Page → Function | a signed page session (JWT, 30 min) | that a valid link was presented recently | in the browser tab, in `sessionStorage` |
| Function → BC | OAuth 2.0 client credentials, Entra app registration | application identity and its assigned BC scope; no browser/link-possession proof | in Key Vault, read through a managed identity |

The vendor never holds a Business Central credential. Business Central mints the
raw link and sends it through the Email module; vendor-facing API calls send only
the hash or token id back to BC. The Function processes the raw token during session
exchange and keeps the BC client credential on the server. The retained e-mail
link is a separate bearer-secret copy covered by §9.7.

## 9.2 The access link

**Generation.** `AMC Access Token Mgt.Issue` produces 256 bits from the platform's
cryptographic random source and returns them base64url-encoded: a 43-character
string with no structure, no meaning and nothing to enumerate.
`AMC Vendor Access Token` stores `SHA-256(token)` as uppercase hex. The raw value
passes to the notification code and becomes part of the HTML/plain-text e-mail
link. That content is retained by the standard Email module and can also remain
with the mail provider and in sender/recipient mailboxes or archives; browser
navigation and session exchange handle the raw token as described in §9.4.
There is no system-wide guarantee that only a hash is stored.

> Verify how your AL runtime exposes cryptographic randomness before coding. If a
> random-bytes API is available, use it. Otherwise `CreateGuid()` is the platform's
> CSPRNG in practice: concatenating three GUIDs and hashing the result with
> `Cryptography Management.GenerateHash(..., HashAlgorithmType::SHA256)` derives a
> 256-bit value from roughly 366 bits of input entropy. Confirm the hex casing that
> `GenerateHash` returns and normalize it — the Function computes the same hash
> independently, and a casing mismatch fails every lookup.

**Validation.** The Function authorizes browser access from the link/session on
every vendor-facing call. AL independently validates token/request/vendor pairing
on writes; general S2S request reads rely on the trusted Function for browser
request scope (§4.7):

| Check | Where | Failure |
|---|---|---|
| the hash exists | Function, `GET vendorAccessTokens` | `LINK-0001` |
| `Status = Active` and `Expires At` in the future | Function, and again in AL on every write | `LINK-0002` / `VCH-AUT-0003` |
| the session is being used for the request it was issued for | Function, from the JWT claims and never from the body | `LINK-0003` |
| the token still belongs to the request being written to | AL, inside `OnInsertRecord` | `VCH-AUT-0004` |
| the request is still open | AL | `VCH-VAL-0001` |

The last two checks protect write consistency: AL derives the vendor/request
pairing from a BC token record instead of trusting a supplied `vendorNumber`.
A token id identifies that record and is not proof of possession of its raw link.
This check prevents mismatched writes, while the Function remains trusted to
authorize the browser and scope reads. Compromise of the shared S2S credential
bypasses that Function authorization boundary (§9.6).

**Lifetime.** The token's states are driven by the request, not by the vendor:

```text
(request sent) --> Active --(opened, any number of times)--> Active
                     |
                     +--(Expires At passed)-------------------> Expired
                     +--(buyer re-sends the link)-------------> Superseded
                     +--(request Closed or Cancelled)---------> Revoked
                     +--(buyer revokes it)--------------------> Revoked
```

`Expires At` is `Issued At` + `Link Validity Days` — fourteen days by default, from
the moment the link was minted rather than from anything about the order. Re-sending
does not extend a link; it mints a new one with a fresh window and supersedes the
old, so a forwarded copy of the previous e-mail stops working immediately.

**The link must outlive the deadline it is asking someone to meet.** Two clocks run
side by side and they answer different questions: `Response Deadline` on the request
is when an answer is wanted, `Expires At` on the token is when the credential dies.
A vendor chased for an answer through a link that already expired is the one
combination that makes the feature look broken, so it is prevented rather than
documented: `Link Validity Days` validates against `Default Response Days` in setup,
and `AMC Request Mgt` re-checks at issue time against the vendor's own
`AMC Response Days` override, refusing with `VCH-REQ-0002` and naming both numbers.

Re-sending mints a new link but does not move `Response Deadline` — the deadline is
a property of the question, not of the envelope it travelled in. A buyer who needs
to give the vendor genuinely more time cancels the request and sends a new one
(§5.1), which is the same path as any other change to the question.

`AMC Token Expiry Job` flips overdue tokens from `Active` to `Expired` on a daily
run, so the request page tells the truth about a link without anyone having to
evaluate a date to find out. It is not what enforces expiry: validation compares
`Expires At` on every call regardless (the table above), so a job that has not run
yet, or is not scheduled at all, never grants access to an expired link. The job
makes the state visible; the comparison makes it real.

Only `Active` and unexpired grants access. Every other state produces the same
"this link no longer works" answer for the vendor; which state it actually was
appears only in telemetry and in the collaboration timeline. Distinguishing the
cases to the caller would only help someone probing.

**Possession of the link is the whole authentication, for every order, whatever it
is worth.** There is no second factor, no step-up above a value, and no per-vendor
switch to turn one on. That is the most questionable-looking line in this design, so
here is why it holds.

*An e-mailed code is not a second factor here.* The obvious step-up — a one-time code
sent when the link is opened — would go to `Sent To E-Mail`: the same mailbox the link
arrived in. Anyone who can read the link can read the code. It would defend only
against a link forwarded *out* of that mailbox, which is a narrow slice and one
vendors create on purpose when an order desk passes work around. A real second
factor needs a channel we do not have and deliberately did not build: no phone
number, no enrolled device, no identity — that was the point of §9.1. Adding a code
would buy friction, a support burden and the appearance of security.

*The order's value is the wrong axis.* This surface carries no payment instruction,
no invoice, no remittance details and no way to change vendor master data — the
vector that actually makes high-value vendor fraud worth attempting does not exist
here. Nor does the projection carry commercial information: `AMC Vendor Request
Line` snapshots item, description, quantity and dates, and **no price** (§4.2). What
a link holder can learn is what the vendor was already sent on the purchase order.
Scaling protection by order value would be protecting an axis nothing is exposed on.

*The compensating control is stronger than a factor would be, and it is universal.*
The worst a stolen link can do is submit a proposal, and a proposal is a statement
of intent that reaches the ERP only after a named buyer reads it and approves it
(§5.2, §7). That check applies to every proposal on every order — not, as a threshold
would, to the ones above a number somebody guessed at.

*What would reopen this.* The answer depends on the surface staying this narrow. If
the vendor page ever exposed prices, documents, other orders, or a way for a vendor
to edit their own master data, possession would stop being enough and this decision
would have to be taken again. That is the trigger to watch, and it is a design
review, not a setting.

**What is never done with a token:**

- never persisted as a raw value or full link in `AMC Vendor Access Token` or
  other AMC application tables; standard Email message content deliberately holds
  the full link and is subject to the access/retention rules of §9.7,
- never written to telemetry, a collaboration entry, a business event payload or a
  Power Automate run history — which is also why the e-mail is sent from Business
  Central rather than from a flow,
- never placed in a query string, where servers and proxies log it; it travels in a
  `POST` body from the page to the Function, and only the initial navigation
  carries it in a path (§9.4),
- never reused across requests, vendors, or re-sends.

## 9.3 The Function as the confidential client

- **BC access:** OAuth 2.0 client credentials, scope
  `https://api.businesscentral.dynamics.com/.default`. The Entra app is registered
  in BC under *Microsoft Entra Applications*, set to **Enabled**, and granted
  **only** `AMC Api Integration` (§4.7).
- **Secrets:** client secret and session signing key in Key Vault, read through the
  Function App's system-assigned managed identity. Nothing in app settings, nothing
  in the repository. V2 replaces the secret with workload identity federation.
- **Token cache:** the BC token is cached in the Function instance until ~5 minutes
  before expiry; one silent re-acquire on a `401`, then fail.
- **Page session:** a JWT signed HS256 with the Key Vault key, claims `jti`,
  `sub` = access token id, `req`, `ven`, `cmp`, `exp` (30 minutes). It never
  contains the raw link, and it is not accepted for any request other than the one
  in its claims. Nothing in it binds to a hostname, so moving the page to a custom
  domain changes no token, no claim and no validation.
- **Rate limiting:** `/api/session` is the only anonymous endpoint and therefore the
  only brute-force surface. A fixed-window counter per client IP and per token-hash
  prefix, kept in Table Storage, returns `429` past the threshold. Failures are
  logged with the IP hashed, never in clear.
- **No business rules.** The Function never decides whether a proposal is legal,
  never computes a quantity, and never edits a payload beyond attaching identity
  fields it derived from the session. The moment it starts to, that logic belongs
  in AL instead.

**Why service-to-service and not a BC user per vendor:** external vendors are not
BC users, would consume licenses, and would have to be provisioned and
deprovisioned in Entra by the buying company — which is exactly the onboarding cost
the link model exists to avoid. BC sees one application identity for all vendors.
The Function enforces browser-session isolation; AL checks the token record pairing
on writes, so a mismatched token/request/vendor payload fails with `VCH-AUT-0004`.
The token id supplies no browser-possession proof to BC and no per-link restriction
on general request reads. This shared identity therefore has broader access than
any one vendor session; V1 accepts that distinction (§4.7, §9.6).

This trade-off — and the fact that it is a *conscious* one with compensating
controls — is what ADR-010 and ADR-013 should record.

## 9.4 The page

`staticwebapp.config.json` carries the part of the security model that lives in the
browser:

- `Referrer-Policy: no-referrer`, so the token in the initial URL cannot leak to
  any third-party host through a `Referer` header,
- `Cache-Control: no-store` on `/r/*`,
- a content security policy with no third-party script origins,
- `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY`,
- `navigationFallback` to `index.html`, so `/r/<token>` is handled by the app,
- the built-in Static Web Apps authentication providers left unconfigured — there
  is nothing here to log into.

On load, the page exchanges the token for a session and then calls
`history.replaceState` to remove it from the address bar. The raw token therefore
does not sit in browser history, in a screenshot, or in a URL the vendor pastes
into a chat with a colleague; everything after the first call uses the session.

## 9.5 A link that no longer works

There is no way for a vendor to obtain a new link from the page. A dead link is a
dead end, and the way out of it runs through the buyer.

**Why not self-service.** The lesser reason is that a public endpoint which causes
an e-mail to be sent is a mail-amplification vector: anyone holding one expired
link, or simply guessing at the endpoint, can make messages arrive at a vendor.
Rate limiting reduces that; it does not remove it. The real reason is the one that
settles it — expiry means access ends **unless a person decides otherwise**. A link
that renews itself on request has an expiry date and no expiry, and the buyer's
control over a credential they issued would exist only on paper.

**What the vendor sees.** One page, the same for every failure: the link no longer
works, and here is who to contact — `Portal Support E-Mail` from setup (§4.2). That
address is *static*. It cannot be the buyer on the request, however much more useful
that would be, because naming a person requires resolving the token, and a page that
says "contact Anna" for one link and "contact us" for another has just told the
holder which links exist. The no-oracle property of §9.2 costs exactly this much, and
this is where it is paid.

**What Business Central records.** Always telemetry: `VCH0124`, with the reason the
token failed. Additionally a `LinkRejected` entry on the request timeline **when the
token resolved** — for an expired, revoked or superseded link, BC knows which
negotiation was being knocked on. An unknown hash belongs to nothing and has no
timeline to be written to, so it stays in telemetry alone.

**How the buyer finds out.** This is what makes the decision workable rather than
merely strict: a rejected access raises the `VendorAccessRejected` business event
(§6.3), so the buyer is told that their vendor just tried a dead link — which is
precisely the moment to press *Re-send link*. Without that, "no self-service" would
mean a vendor waiting on someone who has no idea they are waiting.

## 9.6 Threat model

| Threat | What stops it, or why it is accepted |
|---|---|
| The link is forwarded to someone else | Accepted — this is the deliberate trade-off of the model, the same one an e-signature or parcel-tracking link makes. It is bounded: one request, read and propose only, no prices, no ERP write, every access logged with time and hashed IP, revocable by the buyer, and a named buyer approves anything before it reaches an order. There is no second factor and no step-up by value; §9.2 sets out why one would be theatre on this surface |
| The link is guessed | 256 bits of entropy, no structure to enumerate, no vendor or request identifier in the URL, and rate limiting on `/api/session` |
| The link leaks via `Referer`, browser history or a proxy log | `Referrer-Policy: no-referrer`, HTTPS only, the token stripped from the URL right after exchange, and never present in a query string |
| A mailbox scanner pre-fetches the link | Opening a link changes no business state beyond an access entry, and tokens are multi-use, so a pre-fetch neither consumes nor invalidates it |
| Someone reads AMC token/application tables | These tables contain no generated raw token or full link; the token hash does not reconstruct the raw token |
| Someone reads retained Email content, mailboxes, archives or a BC database copy including Email storage | Message bodies contain the full bearer link and can grant access while its token is active. Hashing the AMC token row does not protect this copy. Restrict Email/body and privileged database access; expiry, revocation and supersession stop the link working even when the message remains (§9.7) |
| The Function's BC credential is compromised | Key Vault/managed identity reduce exposure but do not limit it to one link. An attacker can bypass the Function and read authorized request/line/proposal/token data across vendors and companies covered by the application's effective BC permissions, plus standard data reachable through authorized surfaces. Valid token ids discovered through permitted reads may allow matching proposals/comments for other requests; AL pairing checks do not prove raw-link possession. BC still denies purchasing writes, approval/apply, deletion, setup and token lifecycle writes (§4.7). Disable the BC application, rotate the compromised credential and review cross-vendor access/submissions |
| The Function runtime or session-signing key is compromised | Browser-session isolation depends on the trusted Function. A runtime compromise can use its shared BC access; signing-key compromise can forge session scope. Assess exposure across reachable authorized data and invalidate affected sessions/credentials rather than treating it as a single stolen link |
| A vendor answers another vendor's request | The session claims come from the token, the token is bound to one request, and AL re-validates the pairing on every write (`VCH-AUT-0004`) |
| A submit is replayed, or retried after a timeout | The idempotency key (§8.5) |
| A link outlives the negotiation | `Expires At`, revocation when the request closes or is cancelled, supersession when a new link is sent |
| The page is served over a hostile network | HTTPS only, HSTS from Static Web Apps, no mixed content, no third-party scripts |

## 9.7 Data protection

- No PII beyond a vendor contact e-mail address and a name the vendor types on the
  page when submitting — a business contact acting in a professional capacity.
- Those values sit in an audit trail kept indefinitely (§4.2), on the same basis as
  the purchase documents they belong to: they are part of the commercial record of
  an order. If erasure is ever required for a specific person, `Actor Name` and
  `Sent To E-Mail` are the fields to pseudonymise; the events, the field changes and
  their values have to stay, or the trail stops being one.
- The address a link was sent to is stored on the token, because a buyer must be
  able to see where it went. It is not exposed by any API entity the vendor reads.
- Vendor comments marked `Visible to Vendor = false` are excluded at API page level.
- No raw token, full link, session JWT or client secret is written to AMC tables,
  `Session.LogMessage` or Application Insights. Telemetry carries `vchTokenId`, a
  Guid, and never the token or its hash. Standard Email message bodies are the
  deliberate storage exception for the full bearer link, not a telemetry/audit log.
- `allowDownloadingSource = false`, `includeSourceInSymbolFile = false`.

**Retained e-mail access.** Treat Email Message content associated with Email
Outbox and Sent Email records as bearer-secret material, including both HTML and
plain-text bodies. Restrict standard Email data/page access and configure User
Email View Policies for authorized senders/support. Review related-record policies:
access to an order can also permit viewing its e-mail. These UI policies do not
protect a privileged database export or backup. `AMC Api Integration` must not
receive Email-content read permissions or execute access to Email viewers/body
readers through any assigned role. See [Microsoft Learn — Email view policies](https://learn.microsoft.com/en-us/dynamics365/business-central/admin-how-setup-email#set-up-view-policies).

**Retention is separate from token validity.** Record the environment's retention
periods and cleanup ownership for queued/failed messages, sent bodies, provider
storage, mailboxes, archives and backups. Configure supported standard Email
cleanup/retention for the target BC version; do not assume messages are removed
when the token expires. Keep queued content while delivery/retry is required and
handle abandoned or obsolete messages through the Email module. Revoke/supersede
affected tokens after an exposure. Revocation invalidates the link; it does not
erase existing copies. Email cleanup must preserve the AMC collaboration audit
trail, which has its own lifetime (§4.2). The extension cannot promise deletion
from recipient mailboxes or archives.

Standard storage model: [Microsoft BCApps — Email Message, Outbox and Sent Email](https://github.com/microsoft/BCApps/tree/main/src/System%20Application/App/Email).

---

# 10. Telemetry and observability

Two distinct channels, deliberately not merged:

| Channel | Audience | Content |
|---|---|---|
| `AMC Collaboration Entry` | buyer, auditor | business history: who proposed, who commented, who approved, what changed |
| Application Insights | developer, support | technical: durations, failures, API traffic, conflicts |

They also differ in how long they live, and that is not incidental: the first is
kept indefinitely because it is the record (§4.2), the second expires with its
resource's retention because it is diagnostics. A design that merged them would have
to pick one lifetime and be wrong for the other purpose.

`AMC Telemetry` wraps `Session.LogMessage`. Its AL dictionary uses these stable
logical dimension names (do not add the platform prefix in AL code):

```text
vchEventId, vchRequestNo, vchProposalNo, vchVendorNo, vchOrderNo,
vchLineCount, vchDurationMs, vchResult,
vchErrorCode, vchCorrelationId, vchLineType, vchTokenId
```

**Stored names (BC17+ custom telemetry).** Business Central prefixes custom AL
dimension keys with `al` in Application Insights. For example,
`vchCorrelationId` becomes `customDimensions.alvchCorrelationId`, `vchResult`
becomes `customDimensions.alvchResult`, and `vchEventId` becomes
`customDimensions.alvchEventId`. The platform dimension `customDimensions.eventId`
is not an AL dictionary key: it contains the `EventId` argument supplied to
`Session.LogMessage`, such as `VCH0220`. The wrapper sets its logical
`vchEventId` to that same value.

The Function emits application events as `traces`, with unprefixed custom keys
such as `customDimensions.vchCorrelationId`, `vchResult` and `vchEventId`.
Its `vchEventId` contains the full `vendorapi.*` identifier listed below; the
message text or an SDK-generated event number is not the identifier contract.
The dictionary names remain unchanged on both producers. Queries normalize the
stored names before filtering; renaming keys or changing their meaning under an
existing event id requires a coordinated schema migration.

The target BC version in §2.1 is still unspecified. Confirm the actual emitted
schema in the target sandbox before deploying queries or alerts. This mapping
applies to BC17+ and must not be assumed for an older telemetry implementation.
See [Microsoft Learn — Custom telemetry and dimension prefixes](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-instrument-application-for-telemetry-app-insights).

| Event id | Verbosity | Emitted when |
|---|---|---|
| `VCH0101` | Normal | Vendor request created |
| `VCH0102` | Normal | Vendor request sent |
| `VCH0110` | Warning | Request passed its response deadline |
| `VCH0120` | Normal | Access link issued |
| `VCH0121` | Normal | Access link e-mail handed to the Email module |
| `VCH0122` | Error | Access link e-mail could not be sent |
| `VCH0123` | Normal | Access link opened (with `vchTokenId`, never the token) |
| `VCH0124` | Warning | Access rejected — unknown, expired, revoked or superseded link |
| `VCH0125` | Normal | Access link revoked or superseded |
| `VCH0201` | Normal | Proposal received via API (with payload size, line count) |
| `VCH0202` | Warning | Proposal validation failed (with `vchErrorCode`) |
| `VCH0203` | Normal | Proposal submitted |
| `VCH0210` | Normal | Buyer decision (approve/reject/request changes) |
| `VCH0220` | Normal | Proposal applied (with `vchDurationMs`) |
| `VCH0221` | Error | Apply failed |
| `VCH0230` | Warning | Purchase order unlocked while a request was still unanswered |
| `VCH0240` | Warning | Idempotent duplicate suppressed |

The Function writes to the **same** Application Insights resource, with
`vendorapi.session.issued`, `.session.rejected`, `.request.read`,
`.proposal.forwarded`, `.proposal.rejected` and `.ratelimited`, carrying the same
logical dimension names; their stored keys differ by the AL prefix described
above. One resource lets a normalized query show link issuance/opening, Function
forwarding and AL validation without discarding events from either producer.

`vchCorrelationId` is generated by the page per user action, passed through the
Function, sent in the payload, stored on the proposal, and repeated on related
telemetry events on both sides. A correlation-id query follows that action across
the Function and AL. A negotiation contains several actions; to reconstruct all
of them, use the normalized `requestNo` (or `proposalNo`) and a bounded time window.
Browser activity is represented by Function events; this query reads Function and
BC traces rather than a separate browser telemetry stream.

```kusto
let targetCorrelationId = "8f2c..."; // replace with the actual correlation id
traces
| where timestamp > ago(7d)
| extend eventId = coalesce(tostring(customDimensions.alvchEventId),
                            tostring(customDimensions.vchEventId),
                            tostring(customDimensions.eventId)),
         correlationId = coalesce(tostring(customDimensions.alvchCorrelationId),
                                  tostring(customDimensions.vchCorrelationId)),
         requestNo = coalesce(tostring(customDimensions.alvchRequestNo),
                              tostring(customDimensions.vchRequestNo)),
         proposalNo = coalesce(tostring(customDimensions.alvchProposalNo),
                               tostring(customDimensions.vchProposalNo)),
         result = coalesce(tostring(customDimensions.alvchResult),
                           tostring(customDimensions.vchResult)),
         durationMs = todouble(coalesce(tostring(customDimensions.alvchDurationMs),
                                       tostring(customDimensions.vchDurationMs))),
         errorCode = coalesce(tostring(customDimensions.alvchErrorCode),
                              tostring(customDimensions.vchErrorCode))
| where eventId startswith "VCH" or eventId startswith "vendorapi."
| where correlationId == targetCorrelationId
| extend source = iff(eventId startswith "VCH", "BC/AL", "Function")
| project timestamp, source, message, eventId, correlationId,
          requestNo, proposalNo, result, durationMs, errorCode
| order by timestamp asc
```

For the whole negotiation, replace the correlation-id filter with
`| where requestNo == "VCR-000148"` and choose a time window covering the request's
lifetime. Unknown-link and rate-limit events can lack request/proposal ids; follow
those by correlation id. `coalesce` selects the first non-empty string, and
`todouble` preserves numeric durations (including zero) for subsequent aggregation.
Apply the same normalization to every dashboard/alert query; do not filter on
unprefixed correlation/result keys before this step.

Dashboard KQL queries live in `docs/architecture/telemetry-queries.md`:
proposals/day, rejection rate, median apply duration, forced-unlock rate,
validation-failure breakdown by error code, API error rate.

Telemetry contract verification uses a small mixed trace fixture: an AL VCH event
with al-prefixed keys, a Function vendorapi event with unprefixed keys and the same
correlation id, a VCH trace using only the platform eventId, plus unrelated events.
Run the normalized query in Application Insights/Log Analytics and confirm it
returns the three related rows in timestamp order, excludes the unrelated ones,
preserves result/error values and converts duration strings including "0" to
numbers. Also verify real AL and Function events from the target sandbox share
the documented stored schema; fixture checks alone do not prove emission works.

**Why not log to a BC table for diagnostics:** a technical log table grows without
bound, is inside the transaction that failed (so a rollback erases it), and cannot
be alerted on. Application Insights sits outside the transaction and is the
supported SaaS answer.

---

# 11. Testing

## 11.1 Structure

Fifteen codeunits, `50130–50144` — the block reserved for the test app in §4.1.

```text
bc/test/src/
  Helpers/     AMCTestLibrary.Codeunit.al                  50130
  Request/     AMCRequestTests.Codeunit.al                 50131
  Proposal/    AMCProposalValidationTests.Codeunit.al      50132
               AMCProposalDecisionTests.Codeunit.al        50133
  Apply/       AMCApplyOrchestrationTests.Codeunit.al      50134
               AMCConfirmHandlerTests.Codeunit.al          50135
               AMCChangeQtyHandlerTests.Codeunit.al        50136
               AMCChangeDateHandlerTests.Codeunit.al       50137
               AMCSplitDeliveryHandlerTests.Codeunit.al    50138
               AMCSubstituteItemHandlerTests.Codeunit.al   50139
               AMCCancelRemainderHandlerTests.Codeunit.al  50140
  Locking/     AMCOrderLockTests.Codeunit.al               50141
  Api/         AMCApiTests.Codeunit.al                     50142
  Access/      AMCAccessTokenTests.Codeunit.al             50143
  Notification/AMCNotificationTests.Codeunit.al            50144
```

`AMC Test Library` builds fixtures (vendor with collaboration enabled, PO with
N lines, request, proposal with given line types) so tests read as business
scenarios, not as data setup.

**One test codeunit per handler, not one file with six regions.** The six handlers
are six independent rule sets — that is the whole argument for the interface in
§6.1 — and their tests inherit that property. A single apply-test object would pass
600 lines before the substitution rules were covered, and a test file nobody wants
to open is where coverage quietly stops growing. `AMCApplyOrchestrationTests` keeps
what is genuinely about the orchestrator: the lock check, releasing the order,
rollback on handler failure, and request-line recalculation. Unknown-value coverage
uses the existing `AMCProposalValidationTests` and `AMCApplyOrchestrationTests`:
choose an ordinal absent from the installed enum values, persist it on a proposal
line, re-read it and convert it through the interface. Verify Validate accumulates
the controlled failure alongside errors on other lines, and a later unknown line
rolls back earlier apply writes without changing the stored ordinal. No additional
test codeunit is needed.

`AMCNotificationTests` covers recipient resolution, the builder's output (does the
body carry the link, the right line count, the vendor's language, and no token in a
query string) and a send failure surfacing as `LinkSendFailed` rather than a rolled
back request.

Conventions: `Subtype = Test`, one `[Test]` per behavior,
`Test<Scenario>_<Condition>_<Expectation>` naming, explicit Given/When/Then
comments, `LibraryPurchase` / `LibraryInventory` / `LibraryRandom` /
`LibraryVariableStorage` / `Assert` from the standard test libraries,
`asserterror` + `Assert.ExpectedError` for every error path.

## 11.2 Coverage matrix (the rules that must have tests)

| Rule | Test |
|---|---|
| A vendor request snapshots the PO lines as sent | `Request_Create_CopiesLineSnapshot` |
| A sent request cannot be edited | `Request_Sent_IsNotEditable` |
| A second request cannot be created while one is active | `Request_SecondWhileActive_Fails` |
| Cancelling a request clears the pointer, revokes the token and supersedes open proposals | `Request_Cancel_ReleasesOrderForNewRequest` |
| A closed request leaves the order free for a new one | `Request_Closed_AllowsNewRequest` |
| Proposed quantity > outstanding is rejected | `Validate_QtyAboveOutstanding_Fails` |
| Delivery date in the past is rejected | `Validate_PastDate_Fails` |
| Substitution not in `Item Substitution` is rejected | `Validate_UnregisteredSubstitute_Fails` |
| Splits exceeding `Max Splits per Line` are rejected | `Validate_TooManySplits_Fails` |
| Confirm sets `Promised Receipt Date` | `Apply_Confirm_SetsPromisedDate` |
| Split creates additional purchase lines with correct dates and quantities | `Apply_Split_CreatesLines` |
| A substitution takes the substitute item's own price, not the original's | `Apply_Substitute_RevalidatesPrice` |
| A split that drops below a quantity break logs the price it caused | `Apply_Split_CrossesPriceBreak_LogsPriceRecalculated` |
| An unchanged price writes no `PriceRecalculated` entry | `Apply_PriceUnchanged_LogsNothingExtra` |
| Quantity cannot drop below `Quantity Received` | `Apply_QtyBelowReceived_Fails` |
| Applying an approved proposal releases the order | `Apply_Success_ReleasesOrder` |
| Sending a request on a released order is refused | `Request_ReleasedOrder_Fails` |
| An open request blocks edits, line inserts and deletes on its order | `Lock_OpenRequest_BlocksEdit` |
| An open request blocks releasing the order | `Lock_OpenRequest_BlocksRelease` |
| An unconfirmed order cannot be posted, because it is still `Open` | `Lock_OpenRequest_CannotPost` |
| Unlocking cancels the request, revokes the token and supersedes open proposals | `Lock_Unlock_CancelsRequest` |
| Applying a proposal closes the request and unlocks the order | `Apply_Success_UnlocksOrder` |
| A later handler error rolls back earlier line changes/inserts, release/unlock, request/token changes, applied flags and success audit entries | `Apply_HandlerError_RollsBack` |
| An approval decides the whole proposal — every line is applied | `Decision_Approve_AppliesEveryLine` |
| Apply writes through the lock; success and failure both restore the previous suppression state, and failure keeps the order locked | `Lock_DuringApply_IsSuppressed` / `Lock_ApplyError_RestoresLock` / `Lock_ApplySuccess_RestoresSuppression` |
| A validator collects every failure, not only the first | `Validate_ThreeBadLines_ReturnsThree` |
| An unknown persisted line-type ordinal resolves to the unknown handler and adds a structured validation error without changing data | `Validate_UnknownLineType_ReturnsDomainError` |
| An unknown type after an earlier successful handler rolls back all apply writes, preserves the ordinal and records Apply Failed afterwards | `Apply_UnknownLineType_RollsBackAndRecordsFailure` |
| A split and a substitution produce lines with copied dimensions and UoM | `Builder_NewLine_CopiesDimensions` |
| A split with no free line-number gap fails instead of renumbering | `Builder_NoGap_Fails` |
| An expiry run flips only tokens past their date | `Expiry_Run_ExpiresOnlyOverdue` |
| An expired token is refused even when the expiry job has never run | `Token_Overdue_RejectedWithoutJob` |
| A rejected access on a known token writes `LinkRejected` and raises the event | `Token_RejectedAccess_LogsAndNotifies` |
| A rejected access on an unknown hash writes no timeline entry | `Token_UnknownHash_LeavesNoTrace` |
| Sending to a vendor whose response days exceed link validity fails | `Request_ResponseDaysBeyondLinkValidity_Fails` |
| Re-sending mints a fresh window and does not move the response deadline | `Token_Reissue_ResetsExpiryKeepsDeadline` |
| The e-mail body carries the link and never the raw token in a query string | `Email_Build_ContainsLinkOnly` |
| Issuing and sending a link persists its hash but no generated raw token/full link in AMC application tables | `Token_Issue_StoresHashOnly` / `Notification_Send_NoRawTokenInAmcTables` |
| Standard queued/sent Email content retains the full link; after revocation that retained link no longer grants a session | `Email_StoredBody_ContainsLink` / `Token_Revoke_StoredEmailLink_IsRejected` |
| Re-sending a link supersedes the previous one | `Token_Reissue_SupersedesPrevious` |
| An expired, revoked or superseded token is refused | `Token_NotActive_IsRejected` |
| A token from another request cannot write to this one | `Token_ForeignRequest_IsRejected` |
| A browser session cannot read another request, its lines or proposal status, or attach a comment to a foreign source through the Function | `Function_Session_ForeignResource_IsRejected` |
| Shared S2S request reads can retrieve authorized rows for multiple vendors without a link; the company boundary follows BC assignments | `S2S_RequestRead_IsNotLinkScoped` / `S2S_CompanyScope_FollowsAssignedPermissions` |
| Closing or cancelling a request revokes its token | `Request_Close_RevokesToken` |
| Registering an access changes only Access Count / Last Accessed At and logs LinkOpened; status, hash, vendor, request and expiry stay unchanged | `Token_RegisterAccess_KeepsStatus` / `Token_RegisterAccess_ChangesCountersOnly` |
| The integration role cannot directly modify token data or call lifecycle writes; controlled registerAccess succeeds with Rm | `Permission_ApiUser_CannotModifyTokenDirectly` / `Permission_ApiUser_CannotWriteTokenLifecycle` / `Permission_ApiUser_RegisterAccess_WithIndirectModify_Succeeds` |
| Without indirect m, registerAccess fails despite the API page’s Permissions property | `Permission_RegisterAccess_WithoutIndirectModify_Fails` |
| Ordinary POST/PATCH/DELETE on vendorAccessTokens are refused | `Api_TokenCrud_IsRejected` |
| The token lookup guard accepts only one exact hash or SystemId scope and rejects unscoped, malformed, wildcard, range and multi-value filters | `Api_TokenLookup_ExactScopeOnly` |
| Sending a request with no vendor e-mail address fails loudly, before a token exists | `Request_NoRecipient_Fails` |
| The collaboration address wins over the vendor's general one | `Notification_PortalContactOverridesVendorEmail` |
| A vendor with a language code is written to in it; one without gets the company's | `Notification_VendorLanguage_IsUsed` |
| A build that fails restores the session language | `Notification_BuildError_RestoresGlobalLanguage` |
| A duplicate idempotency key does not create a second proposal | `Api_DuplicateKey_NoSecondProposal` |
| A proposal is write-once over the API — no update, no delete | `Api_SubmittedProposal_NotModifiable` |
| A deep insert whose lines break a cross-line rule writes nothing at all | `Api_DeepInsert_InvalidLines_RollsBackHeader` |
| `AMC Api Integration` cannot approve or apply | `Permission_ApiUser_CannotApprove` |
| Approving without `AMC Collaboration Buyer` fails | `Decision_Approve_WithoutBuyerPermission_Fails` |
| Approval stamp/log and apply share the Codeunit.Run worker transaction; failure removes the approval writes and persists Apply Failed/error/log afterwards | `Decision_ApproveThenApplyFails_LeavesApplyFailed` |
| The caller enters Run without writes; the worker rejects intermediate explicit commits on supported runtimes | `Decision_Approve_ReadOnlyBeforeRun` / `Apply_IntermediateCommit_IsRejected` |
| A retry after failure applies the whole proposal once and restores session flags | `Decision_RetryAfterApplyFailure_AppliesOnce` |
| Illegal status transitions error | `Status_IllegalTransition_Fails` |
| No permission set can delete a collaboration entry | `Log_Entry_CannotBeDeleted` |

The permission tests use `LibraryLowerPermissions` — they are the automated proof
of the domain rule in context §5, and the first ones to run whenever the permission
model changes.

## 11.3 What is not unit-tested

Function ↔ BC HTTP behavior (auth, `429` retry, paging, error mapping) is covered by
integration tests **in the Function solution** against a sandbox, not by AL tests.
AL tests must never make outbound HTTP calls.

Read-isolation tests use two vendors/requests. With vendor A's browser session,
try request/line/proposal ids and comment sources from vendor B, query-option
injection and a different company; the Function must reject or ignore attempts to
widen scope and never return B's data. Check the actual upstream query and returned
ownership, including expanded lines. Separately call BC with the shared S2S
credential and no link/session: changing the vendor filter can return B's
authorized request. That is the documented V1 trust boundary, not a failed
per-link permission test. Confirm a company outside the application's BC-assigned
scope is refused, using the effective deployed permissions. AL tests still check
foreign token/request pairings and denied purchase-order/decision writes.

Sandbox HTTP contract tests verify that `tokenHash` exists as `Edm.String` in
`$metadata`; the exact-hash lookup returns one record for a known hash and no
records for an unknown hash; malformed or broad filters are refused; and the
lookup still works when `$select` excludes `tokenHash`. Verify an unselected
response can contain the hash, while the Function's browser DTO, session claims
and captured diagnostics never contain it. Test keyed `registerAccess` after a
lookup without resending the hash, and confirm its indirect-modify checks from
§4.7 still hold. These are endpoint tests, not just direct AL procedure calls.

For runtime 7.0+ extensibility verification, use a disposable sandbox extension
that adds a line type and its handler: persist a proposal using that type, uninstall
the extension while retaining the proposal data, then validate and apply it. Confirm
the unknown handler is selected and the controlled failures of §6.1 appear. Restore
the extension and verify the original ordinal resolves to its business handler
again; a permitted retry must apply the proposal only once.

Token hashing is tested on both sides against the same fixed vector — one known
token, one expected uppercase-hex digest, asserted in `AMCAccessTokenTests` and in
`TokenHasher` tests. It is the one place where two languages must agree byte for
byte, and a casing or encoding mismatch would break every link with no obvious
cause.

E-mail sending is tested through `AMC Vendor Notification` with the Email module's
test connector. Check that queued/retried and sent message bodies contain the
expected link; explicitly exclude standard Email storage from the AMC-table
hash-only assertion. Assert absence of the generated raw token/full URL in AMC
token, request, proposal and collaboration data, including free-text/log fields,
after issue/send/re-send. Check revocation rejects the link recovered from a
retained message without requiring that message to be deleted.

In the target sandbox, verify a permitted user can view the relevant Email body,
an unauthorized user and the integration identity cannot, and configured Email
cleanup removes eligible messages without erasing the AMC audit trail. Check
actual combined permissions and Email View Policies; the AMC permission set alone
does not prove Email confidentiality. Provider/mailbox/archive/backup retention is
an operational control, not an AL unit-test guarantee. Deliverability itself
(SPF, DKIM, DMARC) is verified once per environment, not in a test.

---

# 12. CI/CD and repository

## 12.1 Pipeline

Use **AL-Go for GitHub** (PTE template) rather than hand-written workflows:
it already implements build, artifact resolution, versioning, test execution,
signing and environment deployment, and it is what BC teams actually use.

```text
.github/workflows/
  CICD.yaml              AL: build + test on push and PR
  PullRequestHandler     AL: build + test only, no publish
  CreateRelease
  IncrementVersionNumber
  Current / NextMinor / NextMajor   scheduled compatibility builds
  vendor-web.yaml        page + Function: build, test, deploy to Static Web Apps
  infra.yaml             Bicep: what-if on PR, deploy on main
```

AL-Go owns the Business Central app; the Azure side is a separate, ordinary
workflow, because the two have different build tools, different test runners and
different deployment targets. They share only the OpenAPI contract in `docs/api/`,
which is the correct amount of coupling.

Repository secrets: `AuthContext` (S2S credentials for the BC sandbox deployment).
Azure deployments authenticate through an Entra workload-identity federation to
GitHub OIDC, so there is no Azure secret in the repository at all — which is worth
doing here precisely because it is the same mechanism V2 applies to the Function's
own BC credential.

Branch policy: `main` protected; work on `feature/<short-name>`; PR requires a green
build + test run and one review (self-review with a written checklist is acceptable
for a solo project — the point is the habit and the PR description).

Commit convention: Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`,
`refactor:`, `chore:`).

## 12.2 Analyzers

`.vscode/settings.json` / `app.json` enable **CodeCop, UICop, PerTenantExtensionCop,
AppSourceCop**, plus `AppSourceCop.json` with `"mandatoryAffixes": ["AMC"]`.
A custom ruleset elevates the rules that matter (missing `DataClassification`,
missing captions, implicit `with`) to errors. Warnings fail the build in CI. The
caption rule is doing double duty here: it is what stops the `AMC` affix leaking
into the user interface (§1).

**Why AppSourceCop on a PTE:** it is the only analyzer that enforces affixes and
breaking-change detection against the previously published version — which is
exactly the discipline needed to talk credibly about upgradeability.

## 12.3 Repository layout

```text
vendor-collaboration-hub/
  README.md
  docs/
    architecture/    context+container diagrams, telemetry-queries.md
    adr/             ADR-001 ... ADR-0NN
    api/             collaboration-v1.yaml, vendor-api-v1.yaml, error-codes.md,
                     postman collection
    business-process/ the end-to-end scenario, screenshots
  bc/
    vendor-collaboration-hub/  test/
  vendor-portal/
    web/   React + TypeScript, deployed to Azure Static Web Apps
    api/   Azure Functions, .NET 9 isolated
  azure/
    infrastructure/  Bicep: SWA, Function App, Key Vault, storage, App Insights
  power-platform/
    power-automate/  power-app/
  .github/workflows/
  .al-go/
```

## 12.4 Upgrade strategy

`AMC Upgrade` (`Subtype = Upgrade`) contains dispatch only; each data change is a
named local procedure guarded by an upgrade tag declared in `AMC Upgrade`, and
`AMC Install` sets all current tags on a fresh install so a new company never runs
historical migrations. Backfills use `DataTransfer`. Every `Get`/`Find*` is guarded
with `if`. No external calls, no `Message`, no `Error` on optional data.

---

# 13. Vendor front end (V1)

Two deployables behind one origin:

```text
                  https://vendorhub.example.com
                  +------------------------------------------+
                  |  Azure Static Web Apps                   |
    vendor  --->  |    /r/<token>  /order  /sent  /expired   |
                  |    React + TypeScript, static files only |
                  +--------------------|---------------------+
                                       |  same origin, no CORS
                  +--------------------v---------------------+
                  |  Azure Function App, linked as /api      |
                  |    session, request, proposal, comment   |
                  |    Key Vault through a managed identity  |
                  +--------------------|---------------------+
                                       |  OAuth 2.0 S2S
                                       v
                              Business Central API
```

## 13.1 Hosting

**Azure Static Web Apps, Standard tier, with a linked ("bring your own") Function
App.**

Why Static Web Apps: the vendor front end is static files plus an API, which is the
exact shape this service is built for. It provides a global CDN, free managed TLS, a
custom domain, per-PR preview environments, `staticwebapp.config.json` for routing
and headers (§9.4), and a GitHub Action that deploys the page and the API together.

Why a *linked* Function App rather than the managed API that Static Web Apps can
host for you: the managed option cannot use a managed identity, and the entire
secret story of §9.3 depends on one. Linking a Function App keeps `/api/*` on the
same origin — so there is no CORS and no cross-site cookie problem — while giving
the Function its own identity, Key Vault access, scaling behaviour and Application
Insights. The Free tier with a managed API is fine for a first spike; it is not
where this design ends.

Everything is described in Bicep under `azure/infrastructure/`: Static Web App,
Function App on a consumption plan, storage account, Key Vault with access granted
to the Function's managed identity, and the Application Insights resource shared
with Business Central (§10).

**Nothing in the application knows its own hostname.** A custom domain is a Static
Web Apps setting and a DNS record, and that is the whole of it: the page calls
`/api` relative to wherever it happens to be served (§13.2), Business Central builds
links from `Portal Base URL` in setup (§4.2), and the page session binds to a request
rather than to an origin (§9.3). The host is therefore a deployment choice that can
be made late and changed afterwards, and keeping it that way is a rule rather than a
happy accident — one absolute URL compiled into the front-end bundle would end it.

The one thing a later change cannot reach is links already delivered. A token minted
under one host is in a vendor's mailbox pointing at that host, so a domain change
after real links have gone out needs the old host left resolving, or those vendors
need a re-send (§9.2).

## 13.2 The page

**React + TypeScript, built with Vite.** Four routes, no framework server, no state
library, no component kit heavier than the job.

Next.js is the alternative worth naming in ADR-014. It is not the choice here
because its value is server rendering and routing conventions, neither of which a
four-route anonymous form needs, and it would place a second server-side runtime
next to the Function that already has to exist.

```text
vendor-portal/web/src/
  routes/
    Resolve.tsx     /r/:token -> POST /api/session, strip the token, redirect
    Order.tsx       the request, its lines, and the answer being built
    Sent.tsx        confirmation, proposal number, what happens next
    Expired.tsx     the link no longer works, and the one support address (§9.5)
  components/
    RequestLine.tsx       one requested line and the answer under it
    SplitEditor.tsx       quantity/date rows for one request line
    SubstituteEditor.tsx  substitute picker, limited to what the request offers
  lib/
    api.ts          typed client, generated from docs/api/vendor-api-v1.yaml
    session.ts      the page session, in sessionStorage
    draft.ts        the unsubmitted answer, in localStorage, keyed by request
```

Rules the page must follow:

- **An unsubmitted answer never leaves the browser.** A vendor may start, walk away
  and come back; `localStorage` keyed by request number is where that lives.
  Applying the context document's ownership test — *which system owns this record?*
  — an unsubmitted answer is owned by neither Business Central nor Azure.
- **One `POST /api/proposal` per submitted answer**, never a sequence of calls.
- **The idempotency key is generated once per submit action** and reused on every
  retry of that action, including retries after a timeout where the page cannot
  know whether the write committed. It is regenerated only when the vendor edits
  the answer and submits again.
- One `correlationId` per user action, sent with every call.
- The token is exchanged for a session and removed from the URL before anything
  else happens.
- The vendor number is never sent, never rendered as an input and never read from
  the URL — it comes from the session.
- A validation failure is shown against the row it belongs to, using the
  `[line s/r]` marker the Function parsed out, never as a raw BC message.
- Nothing is editable except the answer: the request itself is read-only.
- The language comes from the session claim, never from `Accept-Language` or a
  browser setting (§13.4).
- Every call is relative — `/api/…`, never an absolute origin, and never an origin
  read from a build-time environment variable. The page works under whatever host
  serves it (§13.1).

## 13.3 Vendor API (Azure Functions)

**.NET 9 isolated worker, C#.** A typed Business Central client, first-class retry
through Polly, and the Azure SDK and MSAL libraries the token acquisition and Key
Vault access depend on. TypeScript everywhere is the alternative, if one language
across the repository matters more than any of that.

| Method | Route | Auth | Does |
|---|---|---|---|
| `POST` | `/api/session` | anonymous, rate limited | hash the token, resolve it in BC, `registerAccess`, return a 30-minute session and the request |
| `GET` | `/api/request` | page session | the request and its lines, from the session's claims |
| `POST` | `/api/proposal` | page session | attach identity and idempotency key, forward one deep insert, map errors |
| `GET` | `/api/proposal/{number}` | page session | status of a submitted proposal |
| `POST` | `/api/comment` | page session | a vendor comment on the request or a proposal |

```text
vendor-portal/api/src/
  Functions/        one class per endpoint above
  Bc/
    BcTokenProvider.cs  client-credentials acquisition + per-instance cache
    BcApiClient.cs      typed client: paging, 429/Retry-After, backoff, correlation id
    BcErrorMapper.cs    VCH-xxx-nnnn -> LINK- / FORM- / BUSY- (§8.4)
  Access/
    TokenHasher.cs      SHA-256, uppercase hex, matching the AL side exactly
    SessionIssuer.cs    JWT sign and verify against the Key Vault key
    RateLimiter.cs      fixed window per IP and token-hash prefix, in Table Storage
  Models/               generated from docs/api/collaboration-v1.yaml
vendor-portal/api/test/ unit tests + integration tests against a sandbox
```

Rules the API must follow:

- **The Function authorizes every browser read and write.** Verify session signature,
  expiry and configured company; derive request/vendor identity from validated
  claims. Build BC queries internally with both exact request and vendor scope;
  never forward browser-supplied OData filters, `$expand`, `$select` or BC URLs.
  Check that returned headers/lines belong to that request/vendor before serializing
  a portal DTO. For a proposal number or comment source in a route/body, load its
  parent and reject it unless it belongs to the session's request/vendor. Do not
  return foreign data to the browser before that check. These are access controls,
  not ERP quantity/date/substitution rules.
- **Identity comes from the token, never from the body.** `vendorNumber`,
  `requestNumber` and `accessTokenId` are attached from the session; if the body
  contains them, they are overwritten rather than merged.
- **The company is configuration.** `companyId` is an app setting read at startup
  and used to build every BC URL. It is never read from the link, the session, a
  route or a body, and there is no endpoint that takes one (§8.1).
- **No business rules.** It forwards and it translates. Whether 1200 exceeds the
  outstanding quantity is Business Central's answer, not a check duplicated here —
  duplicating it is how the two drift apart and how the ERP stops being the
  authority.
- Retry `5xx` and timeouts with exponential backoff and jitter, at most 3 attempts,
  carrying the same `idempotencyKey` every time; honour `Retry-After` on `429`.
- Treat `VCH-IDM-0000` as success and reuse the returned proposal id.
- Never log a raw token, a token hash, a session JWT or a BC access token. Log
  `vchTokenId`.
- Fail closed: an unexpected error becomes a generic failure plus a correlation id,
  never a leaked BC message.

## 13.4 The e-mail

Built by `AMC Vendor Email Builder`, sent by `AMC Vendor Notification` through the
standard Email module, from whichever account an administrator maps to the
`AMC Vendor Collaboration` e-mail scenario.

The message itself:

- Plain HTML: a summary table and one button. No form, no script, no web font, no
  tracking pixel — mail clients strip or block all of them, and would each do it
  differently.
- A plain-text alternative carrying the same link, because some clients and some
  people read only that.
- The line summary is an excerpt — the first lines and a count. The page behind the
  link is the full document.
- The subject carries the purchase order number, so the thread is findable later.
- `Reply-To` is the buyer, so a vendor who answers by replying — some always will —
  reaches a person rather than a no-reply mailbox.
- Optionally attaches the standard purchase order report as a PDF when
  `Attach Order PDF` is set, reusing `Report Selection - Purchase` instead of
  rendering a document of our own.

**One recipient, resolved in one order.** `Vendor."AMC Portal Contact E-Mail"` if it
is filled, otherwise `Vendor."E-Mail"`. If both are empty, *Send to Vendor
Collaboration* fails with `VCH-REQ-0003` naming the vendor — it does not create a
request that nobody can answer, and it does not queue a message with no destination.
The check runs **before** the token is minted: resolving a recipient is the one part
of `Send` that can fail on data the buyer can see and fix, so it fails first, while
nothing has been written and no credential has been created (§5.1).

The custom field is not a duplicate of `Vendor."E-Mail"`; it exists because that
field is very often the wrong address — accounts payable, or a general inbox — and
overwriting it would redirect every other document BC sends to that vendor. So the
standard field stays the general one and remains the fallback, while the override
records a deliberate choice for this channel. That is the same shape BC itself uses
when it keeps a separate address on a Contact or an Order Address.

**One address, not several.** A link, a token and a recipient are one thing: the
token is what gets revoked, and `Sent To E-Mail` on it is the record of where it
went. Sending one link to several people would make "who answered" unanswerable and
revocation all-or-nothing; sending several links would be a per-recipient credential
model — a real feature, with its own lifecycle, its own revocation surface and its
own "who answered first" semantics, and not something to acquire by accident. In
practice a vendor with several people involved gives one shared order-desk mailbox,
and forwarding beyond that is already the accepted model (§9.6).

**The language is decided once, in Business Central, and travels with the request.**
`Vendor."Language Code"` when it is set, the company's language when it is not,
snapshotted onto `AMC Vendor Request."Language Code"` at send time. The e-mail is
written in it, the API projects it, the Function puts it in the page session, and the
page renders in it. Deciding once is what keeps the e-mail and the page from
disagreeing, and snapshotting is what keeps them agreeing three weeks later after
someone edits the vendor card.

The page does **not** fall back to the browser's `Accept-Language`. The buying
company chose the language it addresses this vendor in; a vendor who opens the link
on a colleague's laptop should see the same document, not a different one.

Two mechanics carry it, and neither is a new subsystem:

- **The strings are ordinary AL `Label`s.** `app.json` already enables
  `TranslationFile` (§1), so the subject, the headings and the button text land in
  the generated `.xlf` with every other label in the app. There is no e-mail
  template table, no per-language body records and no setup page for them — adding
  a language is a translation file, which is the same thing it is everywhere else in
  BC.
- **The data is already translated.** `Purchase Header."Language Code"` comes from
  the vendor, and standard `Purchase Line` validation writes the item's description
  from `Item Translation` on that basis. `AMC Vendor Request Line.Description` is a
  snapshot of that line, so the description the vendor reads is the one standard BC
  already produced. Nothing here translates master data.

The implementation hazard worth naming: `GlobalLanguage` is **session** state, not
transactional. `AMC Vendor Email Builder` sets it, builds subject and body into local
variables, and restores it — and the restore has to happen on the failure path too,
because a rollback will not undo it. A build that errors with the vendor's language
still set leaves the buyer's session speaking it, which is the kind of defect that
gets reported as "BC suddenly went German" and takes a day to trace. The builder
wraps the build in a `[TryFunction]`, restores, then re-raises.

Deliverability is part of this feature, not an afterthought. The sending domain
needs SPF, DKIM and DMARC alignment, or a share of these links will be filtered and
the process will simply look broken to the buyer. `VCH0122` exists so that a failed
send is visible instead of silent. A wrong-but-valid address is quieter still,
because a bounce arrives long after the Email module accepted the message — there
the signal is the request page, where a link sent days ago with `First Accessed At`
still empty is the thing to chase (§4.6).

---

# 14. Delivery plan

Twenty-eight tasks in dependency order, grouped into milestones. Each task is one
pull request: small enough to review in a sitting, large enough to be worth
reviewing, and finished only when there is something to look at in Business Central
rather than only a green test run.

Two obligations every task carries, which the tables below do not repeat:

- **Permission sets grow with the objects.** A task that adds an object and leaves
  it unreachable by `AMC Collaboration Buyer` — or reachable by
  `AMC Api Integration` when it should not be — is not finished (§4.7).
- **`AMC Test Library` grows with the fixtures.** Tests are written in the task that
  creates the behaviour, never deferred to a later one. §11.2 is the checklist of
  which rules must end up covered.

M4 comes deliberately before M5, and M5 before M6: the link and its lifecycle are a
Business Central concern, and settling them inside BC — with tests, before any Azure
resource exists — keeps the security model from being shaped by whatever the hosting
happened to make convenient.

M3, M4, M6 and M9 each end with the ADRs listed in §15.1.

## M0 — Foundation

*Both apps build in CI and install in a sandbox.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 1 | **Repo and pipeline** | AL-Go PTE template; `bc/vendor-collaboration-hub` and `bc/test` projects with the `app.json` of §2.1 (`idRanges` 50100–50129 and 50130–50149); CodeCop / UICop / PerTenantExtensionCop / AppSourceCop with `mandatoryAffixes: ["AMC"]` and the ruleset that promotes missing `DataClassification` and captions to errors; warnings fail the build; the workflows of §12.1 | A push turns CI green, and both extensions appear in *Extension Management* in the sandbox at 1.0.0.0 | DONE |
| 2 | **Setup, install, permissions** | `AMC Collaboration Setup` (50100) with every field of §4.2 and `GetSetup` on the table; setup Card page (50100); `AMC Install` (50109) creating the record, default number series and current upgrade tags; `AMC Upgrade` (50110) as dispatch-only skeleton; the four permission sets (50100–50103) covering what exists so far | Install into a clean company, open *Vendor Collaboration Setup*, and find it already populated with number series and defaults — nothing to type before the feature can be switched on | |

## M1 — The question

*A buyer can capture PO-10482 as a vendor request.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 3 | **Request aggregate** | `AMC Vendor Request` (50101) and `AMC Vendor Request Line` (50102) with all fields and keys of §4.2; enums `AMC Request Status` (50100) and `AMC Request Line Status` (50101); List / Document / Subform pages (50101–50103) | Create a request and two lines by hand, filter the list by vendor and status, and confirm the FlowFields and captions are right | |
| 4 | **Recording** | `AMC Collaboration Entry` (50105); enums `AMC Collab Entry Type` (50104), `AMC Actor Type` (50105), `AMC Source Type` (50106); `AMC Collab Log` (50105) as the only writer, with no update and no delete path; `AMC Collab Timeline` ListPart (50107) on the request; `AMC Telemetry` (50106) with the event-id labels and dimension names of §10 | Write entries from a test codeunit, see them in order on the request, and confirm the page refuses to edit or delete. Emit one telemetry event and find it in Application Insights | |
| 5 | **Create a request from an order** | `AMC Vendor Ext` (50102) and `AMC Purchase Header Ext` (50100); `AMC Request Mgt` (50100) with `CreateFromOrder`, line snapshotting, the one-active-request invariant under a header lock and `VCH-REQ-0001` (§5.1); *Send to Vendor Collaboration* on the Purchase Order page extension (50100), leaving the request in `Draft` because there is nothing to send it with yet | Enable collaboration on a vendor, press the action on an `Open` PO-10482, and get a request whose lines mirror the order. Press it again and be refused by name. Release the order and confirm the action refuses that too. Turn collaboration off on the vendor and be refused again | |

## M2 — The answer, inside Business Central

*A proposal can be entered and validated without an API existing.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 6 | **Proposal aggregate** | `AMC Vendor Proposal` (50103) and `AMC Vendor Proposal Line` (50104) with all fields and keys, including the unique `Vendor No. + Idempotency Key`; enums `AMC Proposal Status` (50102) and `AMC Proposal Line Type` (50103, extensible); List / Document / Subform pages (50104–50106); `AMC Proposal Mgt` (50101) creating a draft against a request | Capture the PO-10482 answer by hand as a `Draft`: two split lines and one substitution, against the request from task 5 | |
| 7 | **Validation** | `AMC Validation Result` (50122) with `AddError`, `HasErrors`, `AsErrorText` and `AsJson`; `AMC Proposal Validator` (50102) with every rule of §0.4 and the `VCH-xxx-nnnn` labels; a *Validate* action on the proposal page | Break each rule in turn on a draft and press *Validate*: quantity above outstanding, a past date, an unregistered substitute, too many splits, a missing reason code. Then break three at once and see three failures, not one | |
| 8 | **Status discipline** | `SetStatus` on `AMC Request Mgt` and `AMC Proposal Mgt` with explicit allowed-transition tables; `Editable = false` on every status control; the transitions of §5.1 and §5.2 | Try to move a proposal from `Draft` straight to `Applied` and be refused. Confirm no page lets a status be typed | |

## M3 — Applying it

*The split-delivery scenario of context §4 works end to end inside Business Central.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 9 | **The interface and the simple handlers** | `AMC IProposalLineHandler`; the `implements` map and runtime-7.0+ `UnknownValueImplementation` on `AMC Proposal Line Type`; `AMC Unknown Line Handler` (50125), with validation/apply domain errors and required execute permissions (§6.1); `AMC Purchase Line Builder` (50123) with gap allocation, `Validate` field ordering and dimension copying; `AMC Confirm Handler` (50111), `AMC Change Qty Handler` (50112), `AMC Change Date Handler` (50113) | Call a handler directly from a test against a real purchase line and watch `Promised Receipt Date` and `Quantity` change through standard validation. Confirm a quantity below `Quantity Received` is refused | |
| 10 | **The structural handlers** | `AMC Split Delivery Handler` (50114), `AMC Substitute Item Handler` (50115), `AMC Cancel Remainder Handler` (50116), all three building lines through the builder from task 9 | Split 1000 into 600 + 400 and see line 15000 appear next to 10000 with the right dates, dimensions and origin stamp. Substitute ITEM-B2 and see the original cancelled. Fill the line-number gap and confirm `VCH-APL-0005` rather than a renumbering | |
| 11 | **Order lock** | `AMC Order Lock Mgt` (50120) with the block list of §7.3, `Suppress` / `Resume`, and the confirm-and-cancel *Unlock Purchase Order* action; `AMC Purchase Events` (50107) subscribing and forwarding only | With a request open on PO-10482, try to change a quantity, add a line, delete a line and release the order — all refused with the same message. Try to post a receipt and watch standard BC refuse it because the order is still `Open`. Unlock, read the confirmation, accept, and watch the request cancel and the vendor's link die | |
| 12 | **Decision and apply** | `AMC Proposal Decision Svc` (50103) with permission checks and logging; `AMC Apply Proposal Svc` (50104) running steps 0–10 of §7.1 through `Codeunit.Run` with its Boolean result captured; caller enters without an open write transaction, restores session flags on both paths and writes `Apply Failed` only after rollback; `PriceRecalculated` logging (§7.2) | Approve the PO-10482 proposal and watch the order become the four lines of §0.4, released and unlocked — and only now receivable. Make a handler fail and confirm the order is untouched, still `Open` and still locked, and the proposal says why | |

## M4 — Asking the vendor

*Pressing Send delivers a real e-mail whose link belongs to one request, expires, and can be revoked.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 13 | **Access token** | `AMC Vendor Access Token` (50106) and `AMC Access Token Status` (50107); `AMC Access Token Mgt` (50117) with `Issue`, `Assert`, `RegisterAccess`, `Revoke`, `Supersede` and `Expire`, storing only the SHA-256 hash (§9.2); no blanket token-write elevation on the shared codeunit (§4.7); pages 50109 and 50110 | Issue and send a token from a test: confirm no generated raw value/full link appears in AMC application tables, while the standard Email body contains the expected link (§9.7). Revoke it and watch the status change and the timeline record it. Assert a token against the wrong request and get `VCH-AUT-0004` | |
| 14 | **The e-mail** | `AMC Vendor Email Builder` (50119), pure, returning subject, HTML and plain text; `AMC Vendor Notification` (50118) resolving the recipient and sending through the Email module; `AMC Email Scenario Ext` (50100); the language rules and the `GlobalLanguage` restore of §13.4 | Configure an e-mail account, map the scenario, and send yourself the message for VCR-000148. Check it renders in a real client, that the plain-text alternative carries the same link, and that a vendor with a language code gets that language | |
| 15 | **Send, re-send, revoke, expire** | `Send` moving `Draft → Sent → Awaiting Vendor`, minting the token and handing over the e-mail in one transaction (§5.1); *Re-send link* and *Revoke link* actions; the `VCH-REQ-0002` and `VCH-REQ-0003` guards; `AMC Token Expiry Job` (50124) and the setup action that schedules it | Press *Send* on PO-10482 and receive the e-mail. Press *Re-send* and confirm the first link's token is `Superseded`. Set `Link Validity Days` below the vendor's response days and be refused. Run the job against a back-dated token and watch it flip to `Expired` | |

## M5 — The contract

*The whole scenario runs from Postman with a service-to-service token.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 16 | **Read API** | API pages `vendorRequests` (50120), `vendorRequestLines` (50121) and `vendorAccessTokens` (50125) with a read-only `tokenHash` property in metadata, an exact hash/id scope guard, `$select` excluding the hash and the `registerAccess` bound action (§8.2); page 50125 alone elevates token M in the integration path, backed by role Rm and counter-only updates (§4.7); the Entra application registration, enabled in BC and granted `AMC Api Integration` only | Acquire an S2S token, resolve a real link's hash, then read the request and its lines. Try to list `vendorAccessTokens` without a filter and be refused. Verify direct S2S can read another authorized vendor’s request without a link, while the Function rejects that same foreign read under the original browser session; verify the BC-assigned company boundary | |
| 17 | **Write API** | `vendorProposals` (50122) with the nested `vendorProposalLines` part (50123) and the nine-step `OnInsertRecord` of §8.3; `collaborationComments` (50124); `AMC Idempotency Mgt` (50121); the error contract of §8.4 and the generated `docs/api/error-codes.md`; `docs/api/collaboration-v1.yaml` | Post the whole PO-10482 answer in one call and get `201`. Post it again with the same key and get `VCH-IDM-0000` with the original id. Break one line and confirm nothing at all was written. Try to PATCH the proposal and be refused | |

## M6 — The middle tier

*The flow runs from `curl`, starting from nothing but a link.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 18 | **Azure infrastructure** | Bicep under `azure/infrastructure/` for the Static Web App, the linked Function App, storage, Key Vault and the shared Application Insights (§13.1); GitHub OIDC federation so no Azure secret lives in the repo; the `infra.yaml` and `vendor-web.yaml` workflows | A workflow run provisions the resources, and a health endpoint answers on the Static Web App's own origin under `/api` | |
| 19 | **Session and request** | `TokenHasher` matching the AL digest byte for byte against the shared vector (§11.3); `BcTokenProvider` and `BcApiClient` with paging, `Retry-After` and backoff; `SessionIssuer`; `RateLimiter`; `POST /api/session` and `GET /api/request` | `curl` a real link's token and get a session and the request back. Use an expired link and get `LINK-0002`. Hammer the endpoint and get `429` | |
| 20 | **Proposal and comment** | `POST /api/proposal`, `GET /api/proposal/{number}`, `POST /api/comment`; identity attached from the session and never merged from the body; `BcErrorMapper` producing the `LINK-` / `FORM-` / `BUSY-` codes of §8.4; retry carrying one idempotency key | `curl` the whole answer through the Function and watch the proposal appear in BC. Send a body claiming another vendor and confirm it is overwritten, not honoured. Break a line and get `FORM-0001` naming the row | |

## M7 — The vendor's page

*A vendor answers PO-10482 on a phone, having received only an e-mail.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 21 | **Shell and resolve** | Vite + React + TypeScript project; `staticwebapp.config.json` with the headers and fallback of §9.4; the `/r/:token` route exchanging the token and stripping it with `history.replaceState`; the read-only order view; the expired page showing `Portal Support E-Mail` | Click the link in the e-mail on a phone and see PO-10482. Check the address bar no longer holds the token and the back button does not restore it. Open a revoked link and get the same page as an unknown one | |
| 22 | **Answer and submit** | `RequestLine`, `SplitEditor` and `SubstituteEditor`; the `localStorage` draft; one `POST` per submit with a key generated once per attempt; per-row error highlighting from the `[line s/r]` marker; the sent page | Build the 600 + 400 + ITEM-B2 answer on a phone, close the tab halfway, reopen the link and find the draft. Submit, and watch the proposal reach the buyer's queue in BC | |

## M8 — Seeing it

*One query shows a whole negotiation; the buyer has a worklist rather than a search.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 23 | **Telemetry and dashboard** | AL VCH events and Function vendorapi events from §10 emitted with stable logical dimensions; `vchCorrelationId` threaded from the page through the Function into AL; `docs/architecture/telemetry-queries.md` with prefix normalization before filters and dashboard queries | Verify mixed AL/Function traces and the target sandbox schema. Follow one action by correlation id, then the whole negotiation by requestNo in a bounded time window, including link and apply events in order | |
| 24 | **Buyer surfaces** | `AMC Collab Activities` CardPart (50108); the Purchasing Agent role centre extension (50103); the Purchase Order List (50101) and Purchase Order Subform (50104) extensions; the Vendor Card extension (50102) | Open the role centre and find the proposals awaiting review in a cue that opens the filtered list. On the order, see which lines came from which proposal | |

## M9 — Power Platform

*The buyer is notified where they already are, and can decide from a phone.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 25 | **Business events and notification** | `AMC Business Events` (50108) publishing the six events of §6.3; a Power Automate flow turning `VendorProposalSubmitted` into a Teams message with a deep link, and `VendorAccessRejected` into a prompt to re-send | Submit a proposal from the vendor page and get the Teams message. Open a dead link as the vendor and watch the buyer be told to re-send | |
| 26 | **Power App review** | A canvas app listing proposals awaiting review and calling `AMC Proposal Decision Svc` through the API, with the same permission and version checks | Approve from a phone and watch the purchase order change. Approve one whose order moved in the meantime and get the same `Superseded` outcome as in the client | |

## M10 — Presentable

*The project can be walked through by someone who has not seen it.*

| # | Task | Delivers | See it work | Status |
|---|---|---|---|---|
| 27 | **Architecture decision records** | The fifteen ADRs of §15.1, each written from its source sections and its decision numbers | Someone can ask "why is there no second factor" and be handed one page that answers it | |
| 28 | **README, diagrams, demo script** | `README.md`; the context and container diagrams under `docs/architecture/`; the end-to-end scenario with screenshots under `docs/business-process/`; a demo script that runs PO-10482 from an empty company | A clean sandbox, the script, and twenty minutes produce the whole story in front of an audience | |

---

# 15. Decision log — why these choices

| # | Decision | Alternatives rejected | Reason |
|---|---|---|---|
| 1 | Two apps (main + test) | tests inside main; three-app split | test code must not ship; a Core/API/UI split has no consumer, licensing or cadence justification yet |
| 2 | Feature folders, `internal` modifiers | object-type folders | keeps one capability in one place, keeps a later split cheap |
| 3 | Request as an immutable snapshot | reading the PO live at answer time | a vendor's answer is only interpretable against the question that was asked |
| 4 | Proposal immutable after submit, new proposal supersedes | editable proposal | this is what creates real negotiation history instead of last-write-wins |
| 5 | Vendor confirmation stored in `Promised Receipt Date` | custom `AMC Confirmed Date` | the standard field already carries that meaning and feeds planning; a custom one forks the truth |
| 6 | Reuse `Reason Code` and `Item Substitution` | custom reason/substitute tables | the master data and its governance already exist |
| 7 | Split delivery creates real purchase lines | custom delivery-schedule table | receipts, planning, availability and reporting only understand purchase lines |
| 8 | Enum implements `IProposalLineHandler`, one codeunit per business line type plus UnknownValueImplementation for unknown persisted ordinals (BC18+) | `case` statement in the apply service; treating a removed enum value as Confirm or skipping it | six independently testable rule sets and a genuine extension point; removed extension values produce a controlled domain failure with no partial apply (§6.1) |
| 9 | No `IsHandled` events | classic BC override pattern | an `IsHandled` here would let a third party skip the validation that justifies the whole layer |
| 10 | An open request locks its purchase order for editing; unlocking cancels the request | an order-version counter compared at approval time; a platform ETag; timestamp comparison | a counter detects the conflict only after the vendor has answered and the buyer has decided, when the only remedy left is to start again. The lock moves the same decision to the front, where a person is present, and removes a header field, a request field, a proposal field, an API field, an error code and the whole question of which changes count as collaboration-relevant. The cost — an order frozen while a vendor answers — is paid by one action with a warning |
| 11 | Custom API pages | standard pages as web services; SOAP/OData-bound codeunit | a published standard page is a leaky, unversioned contract that exposes `Purchase Line` for writing; a codeunit action loses `$filter`, `$expand`, paging and ETags |
| 12 | Requests are read-only over the API | vendor-creatable requests | the vendor answers work, it never creates work |
| 13 | **One atomic POST with nested lines (deep insert), validated and submitted in a single transaction** | create draft → add lines → `submit` action; bound action with a JSON payload | validation here is cross-line, so incremental inserts validate nothing until the last call; one call makes the idempotency key cover exactly one operation; an unsubmitted answer is client state, not ERP state. The JSON-payload action stays as the fallback if deep insert cannot return usable per-line errors |
| 14 | `idempotencyKey` in the **body**, unique index | `Idempotency-Key` HTTP header | a BC API page cannot read request headers — this is a platform constraint, not a preference |
| 15 | `VCH-xxx-nnnn` prefix in every error message | relying on `error.code` | BC controls `error.code`; a prefixed message is the only stable machine-readable channel |
| 16 | Shared S2S application, Function-enforced browser isolation, AL write-pairing checks | one BC user per vendor; delegated auth; claiming the shared permission set isolates reads per link | keeps onboarding simple; accepts cross-vendor application read scope within assigned BC companies. Credential compromise affects that full scope, while buyer decisions and purchasing writes remain denied (§4.7, §9.6) |
| 17 | `AMC Api Integration` cannot approve, apply or delete | one broad permission set | makes "the vendor cannot change the PO" a platform guarantee rather than a convention |
| 18 | Business events for Power Automate | polling flows; HTTP calls from AL | polling costs a run per interval and adds latency; calling HTTP from AL puts retry/timeout inside the ERP transaction |
| 19 | Two channels: BC audit log + Application Insights | one of them only | business history must be readable in BC and survive; technical diagnostics must survive a rollback and be alertable |
| 20 | Validator is side-effect-free and separate | validation inside apply | it is called from API, UI and tests, and must be testable without writing a purchase order |
| 21 | Approval and apply share one Codeunit.Run worker transaction; caller has no open write transaction, restores session flags on both paths and writes failure state after rollback | per-line commits; TryFunction as a rollback boundary | a partially applied purchase order is worse than a failed one |
| 22 | AL-Go for GitHub | hand-written workflows | it is the tooling BC teams actually use, and it already solves versioning, artifacts and deployment |
| 23 | AppSourceCop enabled on a PTE | PTE cop only | it is the only analyzer enforcing affixes and breaking-change detection — the upgradeability discipline |
| 24 | Vendor access is an e-mailed, single-purpose link | a vendor portal with accounts; Power Pages; an application distributed to vendors | every account-based option is paid for per vendor before any value appears, and needs the vendor's own IT to cooperate; a link arrives in the channel already used for purchase orders and works on a phone |
| 25 | The e-mail carries a link, not a form | an interactive form in the message body | mail clients strip or ignore forms and scripts and disagree with one another; a hyperlink is the only element that behaves the same everywhere |
| 26 | Extend the standard Purchasing Agent role center | ship a custom role center | buyers already work there; a new profile fragments their day |
| 27 | Objects are allocated by responsibility; the range is spent, not saved | folding seams into their callers to keep IDs free for later versions | the licence grants 50100–50149 per object type and the model needs 40 of the 50 codeunit slots. Holding IDs back for versions that do not exist buys nothing now and costs testability now; §4.1 states the rule that governs adding one |
| 28 | `AMC Order Lock Mgt` separate from `AMC Purchase Events` | the lock rules inside the subscriber codeunit | a subscriber should dispatch and nothing else; logic inside one can only be reached by making the platform fire an event, and what a locked order refuses, what unlocking costs and when apply may write anyway are the rules that keep the whole design honest |
| 29 | `AMC Validation Result` instead of `List of [Text]` | a flat list of message strings | a failure is a code, a request line, a sequence and a text; flattening it forces every consumer to parse it back out — which is exactly why §8.4 needed a marker convention — and it is what stops the validator collecting more than one failure |
| 30 | `AMC Purchase Line Builder` shared by the split and substitute handlers | each handler inserting its own purchase lines | gap allocation, `Validate` field order and dimension copying are the same non-trivial operation in both, and a drift between two copies corrupts a purchase order |
| 31 | `AMC Vendor Email Builder` separate from `AMC Vendor Notification` | one codeunit that builds and sends | building is pure and worth asserting against; sending is a side effect. The same seam as validator against apply |
| 32 | One test codeunit per line handler | one apply-test object with six regions | the handlers are six independent rule sets and their tests should be too; a 600-line test file is where coverage stops growing |
| 33 | `AMC Token Expiry Job`, scheduled by an explicit setup action | comparing dates lazily at validation time; a job queue entry created on install | a row that still says `Active` a month after the link died is a lie the buyer reads on the request page; and an extension should not put entries in an administrator's job queue unasked |
| 34 | BC owns token validity; AMC tables store its SHA-256 hash while standard Email content retains the bearer link under separate access/retention controls (§9.7) | a JWT signed by the Function; the token kept in Azure storage | the token shares its lifetime with the request, and the request is a BC record; a self-signed token is hard to revoke, and a token held in Azure could outlive the negotiation that justified it |
| 35 | Tokens are multi-use, expiring, revocable, superseded on re-send | single-use tokens | vendors come back to the page, and corporate mail scanners pre-fetch links; a single-use token breaks both, and turns a scanner's fetch into a fake vendor visit |
| 36 | AL checks active token/request/vendor pairing on writes; Function authorizes browser access | accepting mismatched token/request payloads; treating a token id as raw-link proof | BC rejects inconsistent writes independently, while the trusted Function enforces browser read scope. This does not isolate shared S2S reads or contain credential compromise to one request (§4.7) |
| 37 | Azure Static Web Apps with a linked Function App | the managed API included with Static Web Apps; App Service; a server-rendered app | static files plus an API is exactly the SWA shape, and linking a Function App keeps `/api` same-origin while still getting a managed identity, which the managed API cannot have |
| 38 | The Function holds the only BC credential and carries no business rules | calling BC from the browser; re-validating in the Function as well | a static page cannot hold a secret; and validation written twice, in two languages, drifts |
| 39 | The link is sent by the Business Central Email module | Power Automate; SendGrid or Communication Services from a Function | the standard module provides accounts, scenarios, Sent Emails and outbox retry; its retained message content contains the raw link and requires access/retention controls (§9.7). Another sender would add delivery stores and possible flow/log copies to control |
| 40 | The unsubmitted answer stays in the browser | a draft store in Azure; a `Draft` proposal in BC | an unsubmitted answer is owned by neither system; keeping it local avoids a datastore, a retention policy and a cleanup job for something with no business meaning |
| 41 | A vendor request is created only by an explicit buyer action | creating one automatically when a collaboration-enabled vendor's order is released, or behind a setup flag | releasing an order is not the statement "ask this vendor"; buyers release orders they will send another way, and re-release routinely after edits. An automatic trigger would mint a credential and e-mail a third party as a side effect of a standard internal action, and a setup flag would only make that behaviour harder to predict |
| 42 | One non-terminal request per purchase order, enforced under a header lock | several concurrent requests per order; silently closing the previous one on a second *Send* | one active question is what lets a link resolve unambiguously and outstanding quantities be computed against a single snapshot; and a silent replacement would discard a submitted proposal that a person still owes an answer to, so the second *Send* refuses and the buyer chooses *Re-send link* or *Cancel* |
| 43 | A buyer decision is all-or-nothing per proposal, and `Partially Applied` is not in the status enum | per-line accept/reject; keeping the value in the enum for a possible later answer | a proposal is one business statement whose lines are priced and planned against each other, so unpicking it agrees to something the vendor never offered — *Request Changes* is the answer, and it brings back a proposal the vendor stands behind. The enum is public and extensible, so a value that is unreachable by construction can only ever become a breaking change to remove |
| 44 | Standard price calculation decides the price after any applied change, and a moved price is logged as `PriceRecalculated` | pinning the original unit cost across a substitution; computing a price in this extension; blocking apply above a price-delta threshold | prices, price lists, quantity breaks and discounts are a BC subsystem with their own setup and date logic, and an ERP extension that forms its own opinion about cost forks the truth. What the extension owes the buyer is visibility, not arbitration — hence a dedicated entry type for the one change nobody requested |
| 45 | One Business Central company per vendor-facing deployment; `companyId` is a Function app setting | a company id in the link or the session; a multi-company vendor surface | pinning the company removes an entire class of cross-company probing and keeps the token lookup a single, unambiguous query. Serving a second company is then a second configuration rather than a contract change — and carrying a company in the link would require resolving a token before knowing which company to ask, which BC cannot answer in one call |
| 46 | The buyer decision lives in this extension, not in a standard approval workflow | registering the proposal as a workflow document; making a Power Automate approval the decision | a workflow answers "who internally must sign off"; this answers "do we accept the counterparty's offer", which has one legitimate decision-maker and no hierarchy. And approve-and-apply shares one Codeunit.Run worker transaction here, with failure recorded after rollback, so a buyer sees the order change or sees why it could not; a workflow's asynchronous response would turn a visible refusal into an unattended background error. No approval entries, no hierarchy, no thresholds — it does not duplicate what workflows do |
| 47 | `AMC Collaboration Entry` is kept indefinitely, with no delete path and no Retention Policy registration | a retention window on closed documents; registering the table so an administrator could set one | rows accrue per negotiation step, so the volume never becomes the problem a technical log would; and registering the table would hand out a supported way to erase the audit trail that every other rule in this design protects. Diagnostics that do need a window live in Application Insights, which is why the two channels are separate |
| 48 | A link lives 14 days from issue, re-sending mints a new one, and a daily job makes expiry visible | expiring lazily at validation time; tying the link's life to the response deadline; extending an existing link on re-send | a row that still says `Active` a month after the link died is a lie the buyer reads on the request page, so the state is materialised — but validation compares the date regardless, so the job is never load-bearing. Tying the two clocks together would conflate "when we want an answer" with "when the credential dies"; keeping them separate, with a guard that the link outlives the deadline, keeps both meanings |
| 49 | One recipient per link: `AMC Portal Contact E-Mail`, falling back to `Vendor."E-Mail"`, failing loudly if neither exists | reading the order's contact or order address; sending to several addresses; falling back silently to no send | a token, a link and a recipient are one thing — several recipients would make "who answered" unanswerable and revocation coarse, and several tokens would be a per-recipient credential model acquired by accident. The custom field does not duplicate `Vendor."E-Mail"`; it exists because that address is usually accounts payable, and overwriting it would redirect every other document BC sends |
| 50 | Language is `Vendor."Language Code"` falling back to the company's, snapshotted on the request and used by both the e-mail and the page | an e-mail template table with per-language bodies; letting the page follow the browser's `Accept-Language`; resolving the language at render time | labels plus the `TranslationFile` pipeline already solve per-language text, so a template table would be a second translation mechanism to maintain; and deciding the language once and snapshotting it is what stops the e-mail and the page disagreeing after someone edits the vendor card. Item descriptions need nothing at all — standard `Item Translation` already wrote them onto the purchase line the request snapshots |
| 51 | A vendor cannot request a new link from the page; the buyer re-sends, prompted by a `VendorAccessRejected` event | a self-service "send me a new link" button, rate limited; a generic contact page with no notification | a link that renews itself on request has an expiry date and no expiry, and the buyer's control over a credential they issued would be nominal. The endpoint would also be an unauthenticated way to make e-mail arrive at a vendor. Notifying the buyer is what keeps the strictness workable — otherwise a vendor waits on someone who does not know they are waiting |
| 52 | Possession of the link is the whole authentication, on every order regardless of value | an e-mailed one-time code on open; a step-up above a value threshold; a per-vendor second-factor switch | a code sent to the mailbox the link arrived in is not a second factor, and a real one needs a channel this design deliberately does not have. Value is the wrong axis: the surface carries no prices, no payment details and no master-data write, so nothing scales with the order's worth. The universal control — a named buyer approving every proposal before it reaches the ERP — is stronger than a threshold, and applies everywhere |
| 53 | Nothing in the application knows its own hostname | compiling the origin into the front-end bundle; hard-coding a link host in AL; binding the page session to an origin | the page calls `/api` relative to where it is served, BC builds links from `Portal Base URL`, and the session binds to a request — so the domain stays a deployment choice that can be made late and revised. The one thing it cannot outrun is links already in vendors' mailboxes, which keep pointing at the host that minted them |
| 54 | The vendor's confirmation is what releases the purchase order; a request can only be sent on an `Open` one | a custom confirmation status; a subscriber blocking receipt, posting and invoicing while a request is open | `Released` already means "committed and may be acted on" and already gates posting, so mapping the confirmation onto it makes an unconfirmed order un-receivable through standard Business Central, with no code of ours in that path. It also closes a hole the lock alone leaves: a receipt posted mid-negotiation changes `Quantity Received`, which can make an otherwise valid proposal impossible to apply — the same late failure the lock exists to prevent |
| 55 | A vendor is told a link "no longer works", never why | distinguishing expired / revoked / unknown to the caller | the distinction helps nobody except someone probing; the real reason is in telemetry and in the timeline, where the buyer can act on it |

## 15.1 ADRs to write from this document

| ADR | Source section |
|---|---|
| ADR-001 Vendors cannot modify purchase orders directly | §3, §7, §9.1 (decisions 3, 4, 12, 17, 41, 42) |
| ADR-002 Business Central as source of truth | §3.1, §7.2 (decisions 5, 6, 7, 44) |
| ADR-003 Critical business logic stays in AL | §5.2, §6, §7 (decisions 8, 9, 18, 20, 43, 46) |
| ADR-004 Custom API design | §8 (decisions 11, 13, 14, 15, 29) |
| ADR-005 Power Automate responsibilities and the e-mail channel | §6.3, §13.4 (decisions 18, 39, 50) |
| ADR-006 E-mailed access link vs a vendor portal with accounts | §9.2, §13 (decisions 24, 25) |
| ADR-009 Telemetry strategy | §4.2, §10 (decisions 19, 47) |
| ADR-010 Authentication strategy | §9 (decisions 16, 17, 25, 52) |
| ADR-011 Locking the purchase order under an open request | §5.1, §7.3 (decisions 10, 28, 54) |
| ADR-012 Idempotency over Business Central APIs | §8.5 (decision 14) |
| ADR-013 Vendor access token design | §9.2, §9.5, §9.6 (decisions 34, 35, 36, 48, 49, 51, 52, 55) |
| ADR-014 Static Web Apps + Functions as the vendor front end | §8.1, §13 (decisions 37, 38, 40, 45, 53) |
| ADR-015 Object granularity and the ID range | §4.1, §4.5 (decisions 27–33) |
