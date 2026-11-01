# Diagnostyka analizatorów AL

Stan: 2026-11-01. Wyniki kompilacji z analizatorami skonfigurowanymi w projektach `vendor-collaboration-hub` (App) i `Test`.

Łącznie: **0 błędów, 4 ostrzeżenia i 647 informacji**. Liczby w tabelach oznaczają wystąpienia komunikatów. **PC0037: 0 wystąpień.**

## Warning — według kodu reguły

| Kod | Opis | App | Test | Razem |
|---|---|---:|---:|---:|
| `AS0081` | Ostrzeżenie dotyczące `internalsVisibleTo` | 1 | 0 | 1 |
| `AS0092` | Brak konfiguracji Application Insights | 1 | 1 | 2 |
| `LC0090` | Zbyt wysoka złożoność poznawcza | 1 | 0 | 1 |

## Info — według kodu reguły

| Kod | Opis | App | Test | Razem |
|---|---|---:|---:|---:|
| `AC0019` | Wartość enum o numerze 0 powinna mieć pustą nazwę i caption | 7 | 0 | 7 |
| `AC0031` | Brak jawnej deklaracji uprawnienia do operacji na tabeli | 0 | 414 | 414 |
| `DC0004` | Publiczna procedura bez dokumentacji XML | 85 | 15 | 100 |
| `DC0007` | Publiczny obiekt bez dokumentacji XML | 62 | 2 | 64 |
| `LC0031` | `LockTable()` zamiast `ReadIsolation(UpdLock)` | 4 | 0 | 4 |
| `PC0030` | Brak `SetLoadFields` przed odczytem | 20 | 38 | 58 |

## Pozostawione świadomie — AC0019

Wszystkie 7 zgłoszeń pozostaje aktywnych. Wartości o numerze 0 mają znaczenie biznesowe zgodne z `Docs/project-doc.md` §4.4 oraz maszynami stanów §5:

| Enum | Wartość 0 |
|---|---|
| `AMC Request Status` | `Draft` |
| `AMC Request Line Status` | `Open` |
| `AMC Proposal Status` | `Draft` |
| `AMC Collab Entry Type` | `Comment` |
| `AMC Actor Type` | `Buyer` |
| `AMC Source Type` | `Request` |
| `AMC Access Token Status` | `Active` |

Zastąpienie tych wartości pustą nazwą i caption zmieniłoby prezentację oraz kontrakt istniejących danych. Przenumerowanie wartości biznesowych i dodanie pustej wartości 0 wymagałoby osobnej decyzji projektowej, migracji danych i przeglądu wartości domyślnych. Nie zastosowano wyciszeń ani zmian reguł.

## Pozostawione świadomie — LC0031

Zachowawczo pozostawiono 4 wywołania `LockTable()`:

| Obiekt / procedura | Powód |
|---|---|
| `AMC Request Mgt.CreateFromOrder` | Izolacja tabeli nagłówka obejmuje bufor wywołującego i niezależne bufory kontroli blokady zamówienia podczas tworzenia żądania (§5.1, §7.3). |
| `AMC Request Mgt.Cancel` | Anulowanie i zagnieżdżone kontrole nagłówka korzystają z dotychczasowego stanu izolacji całej transakcji (§7.3). |
| `AMC Request Mgt.Send` | Ścieżka używa kilku buforów żądania i standardowego modułu Email. `LockTable` kończy swój wpływ wraz z transakcją, podczas gdy ustawienie `ReadIsolation` na przekazanym rekordzie mogłoby pozostać aktywne po standardowym `Commit`. |
| `AMC Proposal Mgt.BeginApiSubmission` | Izolacja obejmuje także inne bufory propozycji używane przez deep insert i jego finalizację (§8.3). |

`ReadIsolation(UpdLock)` dotyczy instancji rekordu, a `LockTable()` wpływa na odczyty tej tabeli w całej transakcji. Mechaniczna zamiana nie zachowałaby zakresu działania. Dalsza zmiana wymaga osobnej weryfikacji całego przepływu i testów wielosesyjnych; nie wyciszono reguły. W 4 lokalnych miejscach zastosowano `ReadIsolation(UpdLock)` przed chronionym odczytem.
