# Diagnostyka analizatorów AL

Stan: 2026-10-31. Wyniki kompilacji z analizatorami skonfigurowanymi w projektach `vendor-collaboration-hub` (App) i `Test`.

Łącznie: **0 błędów, 110 ostrzeżeń i 1083 informacje**. Liczby w tabelach oznaczają wystąpienia komunikatów. **PC0037: 0 wystąpień.**

Weryfikacja po poprawkach: oba projekty skompilowane z analizatorami z konfiguracji VS Code (App: 71 plików AL, Test: 19), po odświeżeniu zależności App w Test. Usunięto z zestawienia rozwiązane zgłoszenia; nie wyłączano reguł. Nie publikowano aplikacji ani nie uruchamiano testów w sandboxie.

## Warning — według kodu reguły

| Kod | Opis | App | Test | Razem |
|---|---|---:|---:|---:|
| `AA0139` | Możliwe przekroczenie długości tekstu | 22 | 5 | 27 |
| `AC0010` | Obiekt nie jest objęty PermissionSet | 0 | 19 | 19 |
| `AL1025`* | Pliki XML wyników nie pasują do rozpoznanej definicji | 0 | 18 | 18 |
| `AS0081` | Ostrzeżenie dotyczące `internalsVisibleTo` | 1 | 0 | 1 |
| `AS0092` | Brak konfiguracji Application Insights | 1 | 1 | 2 |
| `LC0010` | Zbyt wysoka złożoność cyklomatyczna | 5 | 0 | 5 |
| `LC0090` | Zbyt wysoka złożoność poznawcza | 1 | 0 | 1 |
| `PC0027` | Walidacja lub triggery na rekordzie tymczasowym | 5 | 32 | 37 |

\* `AL1025` pochodzi z **kompilatora**, nie analizatora. Zatem 110 ostrzeżeń obejmuje **92 z analizatorów i 18 z kompilatora**.

## Info — według kodu reguły

| Kod | Opis | App | Test | Razem |
|---|---|---:|---:|---:|
| `AC0019` | Wartość enum o numerze 0 powinna mieć pustą nazwę i caption | 7 | 0 | 7 |
| `AC0027` | Etykieta tokenu nie ma sufiksu `Tok` | 18 | 0 | 18 |
| `AC0028` | Brak ToolTip na polu tabeli | 142 | 0 | 142 |
| `AC0030` | Niewykorzystany wynik operacji na rekordzie | 50 | 127 | 177 |
| `AC0031` | Brak jawnej deklaracji uprawnienia do operacji na tabeli | 0 | 414 | 414 |
| `AW0005` | Akcja nie ma właściwości `Image` | 2 | 0 | 2 |
| `AW0006` | Brak właściwości umożliwiających wyszukiwanie strony | 2 | 0 | 2 |
| `DC0001` | `Commit()` bez komentarza uzasadniającego | 0 | 41 | 41 |
| `DC0003` | Pusta instrukcja bez uzasadnienia | 0 | 1 | 1 |
| `DC0004` | Publiczna procedura bez dokumentacji XML | 85 | 15 | 100 |
| `DC0007` | Publiczny obiekt bez dokumentacji XML | 62 | 2 | 64 |
| `DC0009` | Zdarzenie bez dokumentacji XML | 1 | 0 | 1 |
| `FC0002` | Niespójna wielkość liter | 1 | 4 | 5 |
| `LC0031` | `LockTable()` zamiast `ReadIsolation(UpdLock)` | 8 | 0 | 8 |
| `LC0088` | Typ `Option` zamiast enum | 4 | 0 | 4 |
| `LC0098` | Nazwa subskrybenta nie odpowiada konwencji | 9 | 1 | 10 |
| `LC0099` | Nieużywany parametr subskrybenta | 17 | 2 | 19 |
| `PC0029` | Zalecane `CreateSequentialGuid()` dla klucza GUID | 1 | 1 | 2 |
| `PC0030` | Brak `SetLoadFields` przed odczytem | 22 | 38 | 60 |
| `PC0038` | Nie wszystkie ścieżki procedury zwracają wartość | 5 | 1 | 6 |

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
