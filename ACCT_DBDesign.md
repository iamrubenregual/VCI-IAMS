# University Accounting System — Database Design

**System:** VCI-IAMS — Accounting & Financial Management
**Scope:** Full schema, covering the already-built Phase 1 tables (Core Admin, Chart of Accounts, Fiscal Periods) plus the Phase 2 modules (General Ledger, AR, AP, Budgeting, Fixed Assets, Banking).

---

## 1. Design Conventions

- Surrogate keys: `INT IDENTITY(1,1)` for most tables, `BIGINT IDENTITY(1,1)` for high-volume tables (journal lines, transactions, audit logs).
- **Standard audit columns** on every table (omitted from the tables below to save space, but assumed on all of them):
  `CreatedBy NVARCHAR(100) NOT NULL`, `CreatedDate DATETIME NOT NULL DEFAULT GETDATE()`, `ModifiedBy NVARCHAR(100) NULL`, `ModifiedDate DATETIME NULL`.
- **Soft delete / lifecycle**: tables use `IsActive BIT` and/or a `Status` code column rather than hard deletes.
- All money columns: `DECIMAL(18,2)`.
- Every transactional module posts to the General Ledger through `JournalEntries` — no module updates `AccountBalances` directly. Single source of truth, full audit trail from sub-ledger to GL.
- Every table that money flows through carries `DepartmentId` (nullable) so you can report by office/college as well as by account.

---

## 2. Module Map

| # | Module | Purpose | Status | Depends on |
|---|--------|---------|--------|-------------|
| 1 | Core Admin | Users, Roles, Departments, Audit | **Built** | — |
| 2 | Chart of Accounts & Fiscal Periods | Accounts, Fiscal Years/Periods, Balances | **Built** | 1 |
| 3 | General Ledger | Journal entries — the backbone every other module posts to | Design | 1, 2 |
| 4 | Student Accounts Receivable | Tuition/fee billing, payments, scholarships | Design | 1–3 |
| 5 | Accounts Payable | Vendors, purchase orders, bills, payments | Design | 1–3 |
| 6 | Budgeting | Departmental/account budgets per fiscal year | Design | 1–3 |
| 7 | Fixed Assets | Asset register and depreciation | Design | 1–3 |
| 8 | Cash & Bank Management | Bank accounts, transactions, reconciliation | Design | 1–3, feeds from 4 & 5 |
| 9 | Reporting Views | Trial balance, income statement, balance sheet, AR/AP aging | Design | all of the above |

---

## 3. Module: Core Admin & Security *(existing — built)*

### 3.1 `Departments`
| Column | Type | Notes |
|---|---|---|
| DepartmentId | INT IDENTITY PK | |
| DepartmentCode | NVARCHAR(20) UNIQUE | |
| DepartmentName | NVARCHAR(100) | |
| Description | NVARCHAR(500) NULL | |
| ParentDepartmentId | INT FK → Departments NULL | self-referencing hierarchy (colleges → departments → offices) |
| IsActive | BIT | |

### 3.2 `Users`
| Column | Type | Notes |
|---|---|---|
| UserId | INT IDENTITY PK | |
| Username | NVARCHAR(50) UNIQUE | |
| Email | NVARCHAR(100) UNIQUE | |
| PasswordHash / PasswordSalt | NVARCHAR(255) | |
| FirstName / LastName / MiddleName | NVARCHAR(50) | |
| DepartmentId | INT FK → Departments NULL | |
| IsActive / IsLocked | BIT | |
| LastLoginDate | DATETIME NULL | |
| FailedLoginAttempts | INT DEFAULT 0 | |

### 3.3 `Roles`
| Column | Type | Notes |
|---|---|---|
| RoleId | INT IDENTITY PK | |
| RoleName | NVARCHAR(50) UNIQUE | e.g. `System Administrator`, `Accountant`, `Cashier`, `Auditor` |
| Description | NVARCHAR(255) NULL | |
| IsActive | BIT | |

### 3.4 `UserRoles` (many-to-many)
| Column | Type | Notes |
|---|---|---|
| UserRoleId | INT IDENTITY PK | |
| UserId | INT FK → Users (cascade delete) | |
| RoleId | INT FK → Roles (cascade delete) | |
| AssignedBy | NVARCHAR(100) | |
| AssignedDate | DATETIME | |
| — | UNIQUE(UserId, RoleId) | a user can't be assigned the same role twice |

### 3.5 `AuditLogs`
| Column | Type | Notes |
|---|---|---|
| AuditLogId | BIGINT IDENTITY PK | |
| UserId | INT FK → Users NULL | nullable in case the acting account is later removed |
| Username | NVARCHAR(50) | denormalized so the log survives a user record change |
| Action | NVARCHAR(50) | `INSERT`, `UPDATE`, `DELETE`, `VIEW`, `LOGIN`, `LOGOUT` |
| TableName / RecordId | NVARCHAR | which row was affected |
| OldValues / NewValues | NVARCHAR(MAX) NULL | |
| IpAddress / UserAgent | NVARCHAR | |
| ActionDate | DATETIME | |

---

## 4. Module: Chart of Accounts & Fiscal Periods *(existing — built)*

### 4.1 `AccountTypes` (lookup)
| Column | Type | Notes |
|---|---|---|
| AccountTypeId | INT IDENTITY PK | |
| TypeCode | NVARCHAR(20) UNIQUE | e.g. `CA`, `FA`, `CL`, `EQ`, `REV`, `OPEX` |
| TypeName | NVARCHAR(50) | |
| NormalBalance | NVARCHAR(10) | `DEBIT` or `CREDIT` (checked) |
| Category | NVARCHAR(50) | `ASSET`, `LIABILITY`, `EQUITY`, `REVENUE`, `EXPENSE` (checked) |
| DisplayOrder | INT | controls report ordering |
| IsActive | BIT | |

### 4.2 `ChartOfAccounts`
| Column | Type | Notes |
|---|---|---|
| AccountId | INT IDENTITY PK | |
| AccountCode | NVARCHAR(50) UNIQUE | e.g. `1113`, `5210` |
| AccountName | NVARCHAR(200) | |
| AccountTypeId | INT FK → AccountTypes | |
| ParentAccountId | INT FK → ChartOfAccounts NULL | self-referencing hierarchy (header/summary accounts down to postable detail accounts) |
| Description | NVARCHAR(500) NULL | |
| IsHeader | BIT | header accounts group children, can't take postings |
| IsActive | BIT | |
| AllowManualEntry | BIT | should be `0` for header accounts and any system-controlled account |
| Level | INT (1–10, checked) | depth in the hierarchy |
| DepartmentId | INT FK → Departments NULL | optional department-owned account |
| OpeningBalance / OpeningBalanceDate | DECIMAL(18,2) / DATE NULL | |

### 4.3 `FiscalYears`
| Column | Type | Notes |
|---|---|---|
| FiscalYearId | INT IDENTITY PK | |
| FiscalYearCode | NVARCHAR(20) UNIQUE | |
| FiscalYearName | NVARCHAR(100) | |
| StartDate / EndDate | DATE (EndDate > StartDate, checked) | |
| IsClosed | BIT | once closed, no further posting into any period within it |
| IsActive | BIT | |
| ClosedBy / ClosedDate | NVARCHAR(100) / DATETIME NULL | |

### 4.4 `FiscalPeriods`
| Column | Type | Notes |
|---|---|---|
| FiscalPeriodId | INT IDENTITY PK | |
| FiscalYearId | INT FK → FiscalYears (cascade delete) | |
| PeriodCode | NVARCHAR(20) | unique within a fiscal year |
| PeriodName | NVARCHAR(100) | e.g. `January 2026` |
| PeriodType | NVARCHAR(20) | `MONTHLY`, `QUARTERLY`, `SEMI-ANNUAL`, `ANNUAL` (checked) |
| StartDate / EndDate | DATE (EndDate > StartDate, checked) | |
| PeriodNumber | INT | 1–12 for monthly, 1–4 for quarterly |
| IsClosed | BIT | posting is blocked once true |
| IsActive | BIT | |
| ClosedBy / ClosedDate | NVARCHAR(100) / DATETIME NULL | |

### 4.5 `AccountBalances` (period-end summary, for reporting performance)
| Column | Type | Notes |
|---|---|---|
| AccountBalanceId | BIGINT IDENTITY PK | |
| AccountId | INT FK → ChartOfAccounts (cascade delete) | |
| FiscalPeriodId | INT FK → FiscalPeriods (cascade delete) | |
| OpeningBalance | DECIMAL(18,2) | |
| DebitAmount / CreditAmount | DECIMAL(18,2) | period activity |
| ClosingBalance | DECIMAL(18,2) | |
| LastUpdated | DATETIME | |
| — | UNIQUE(AccountId, FiscalPeriodId) | one row per account per period |

**Supporting objects already built:**
- Functions: `fn_GetAccountHierarchyPath`, `fn_GetCurrentFiscalPeriod`, `fn_AccountHasTransactions`, `fn_GetFiscalYearStatus`
- Views: `vw_ChartOfAccountsWithDetails`, `vw_FiscalPeriodsWithYearDetails`, `vw_AccountBalancesSummary`, `vw_ActiveAccountsHierarchy`
- Stored procedures: full CRUD for `ChartOfAccounts` and `FiscalYears`, plus `sp_GetAllFiscalPeriods` and `sp_CloseFiscalPeriod`

**Business rules already enforced:**
- Header accounts (`IsHeader = 1`) should carry `AllowManualEntry = 0` and no opening balance — enforced in `sp_CreateChartOfAccount` / `sp_UpdateChartOfAccount` (worth double-checking your seed data matches this — see the earlier review).
- Parent and child accounts must share the same `AccountTypes.Category`.
- An account can't be un-headered while it still has active children, and its code can't change once it has posted activity.
- Fiscal periods/years block further changes once `IsClosed = 1`.

> This is the one module in the map that's already implemented — included here so the design doc is a complete, standalone reference rather than pointing back to separate script files.

---

## 5. Module: General Ledger

### 5.1 `JournalEntryTypes` (lookup)
| Column | Type | Notes |
|---|---|---|
| JournalEntryTypeId | INT IDENTITY PK | |
| TypeCode | NVARCHAR(20) UNIQUE | `MANUAL`, `AR`, `AP`, `PAYROLL`, `DEPRECIATION`, `ADJUSTMENT`, `CLOSING` |
| TypeName | NVARCHAR(100) | |
| IsActive | BIT | |

### 5.2 `JournalEntries` (header)
| Column | Type | Notes |
|---|---|---|
| JournalEntryId | INT IDENTITY PK | |
| JournalNumber | NVARCHAR(30) UNIQUE | e.g. `JE-2026-000123`, generated |
| FiscalPeriodId | INT FK → FiscalPeriods | must not be a closed period when posting |
| EntryDate | DATE | |
| JournalEntryTypeId | INT FK → JournalEntryTypes | |
| SourceModule | NVARCHAR(30) | `GL`, `AR`, `AP`, `FA`, `BANK` — which module generated it |
| SourceReferenceId | NVARCHAR(50) NULL | PK of the source row (e.g. StudentInvoiceId), for traceability |
| Description | NVARCHAR(500) | |
| Status | NVARCHAR(20) | `DRAFT`, `POSTED`, `REVERSED` |
| TotalDebit / TotalCredit | DECIMAL(18,2) | must be equal before `Status = POSTED` |
| PostedBy / PostedDate | NVARCHAR(100) / DATETIME NULL | |
| ReversalOfJournalEntryId | INT FK → JournalEntries NULL | self-reference for reversing entries |

### 5.3 `JournalEntryLines` (detail)
| Column | Type | Notes |
|---|---|---|
| JournalEntryLineId | BIGINT IDENTITY PK | |
| JournalEntryId | INT FK → JournalEntries | |
| LineNumber | INT | |
| AccountId | INT FK → ChartOfAccounts | must not be a header account |
| DepartmentId | INT FK → Departments NULL | |
| DebitAmount / CreditAmount | DECIMAL(18,2) | exactly one is non-zero per line |
| Description | NVARCHAR(500) NULL | |

**Business rules (enforce in `sp_PostJournalEntry`, not just constraints):**
- Sum of `DebitAmount` = sum of `CreditAmount` across all lines before posting.
- Cannot post to a `FiscalPeriod` where `IsClosed = 1`.
- Cannot post directly to `IsHeader = 1` accounts.
- Posting a journal entry is what updates `AccountBalances` for that account/period — everything else is a read model.

---

## 6. Module: Student Accounts Receivable

### 6.1 `AcademicTerms`
| Column | Type | Notes |
|---|---|---|
| AcademicTermId | INT IDENTITY PK | |
| FiscalYearId | INT FK → FiscalYears | ties billing terms back to the fiscal calendar |
| TermCode | NVARCHAR(20) UNIQUE | e.g. `2026-1ST SEM` |
| TermName | NVARCHAR(100) | |
| StartDate / EndDate | DATE | |
| IsActive | BIT | |

### 6.2 `Students`
| Column | Type | Notes |
|---|---|---|
| StudentId | INT IDENTITY PK | |
| StudentNumber | NVARCHAR(20) UNIQUE | school ID number |
| FirstName / LastName / MiddleName | NVARCHAR(50) | |
| ProgramCode | NVARCHAR(20) NULL | course/program, kept lightweight since Registrar owns the full academic record |
| YearLevel | INT NULL | |
| Status | NVARCHAR(20) | `ACTIVE`, `LOA`, `GRADUATED`, `DROPPED` |
| DepartmentId | INT FK → Departments NULL | owning college/office |

> This table intentionally holds only what billing needs. If a Student/Registrar module already exists elsewhere, replace this with a view or link table instead of duplicating student master data.

### 6.3 `FeeTypes` (lookup)
| Column | Type | Notes |
|---|---|---|
| FeeTypeId | INT IDENTITY PK | |
| FeeCode | NVARCHAR(20) UNIQUE | `TUITION`, `LAB`, `MISC`, `REG` |
| FeeName | NVARCHAR(100) | |
| RevenueAccountId | INT FK → ChartOfAccounts | GL account this fee posts to |
| IsActive | BIT | |

### 6.4 `FeeStructures` / `FeeStructureLines`
| Table | Key columns |
|---|---|
| `FeeStructures` | FeeStructureId PK, AcademicTermId FK, ProgramCode, YearLevel, StructureName |
| `FeeStructureLines` | FeeStructureLineId PK, FeeStructureId FK, FeeTypeId FK, Amount DECIMAL(18,2) |

### 6.5 `StudentInvoices` (header) / `StudentInvoiceLines`
| Column | Type | Notes |
|---|---|---|
| StudentInvoiceId | INT IDENTITY PK | |
| StudentId | INT FK → Students | |
| AcademicTermId | INT FK → AcademicTerms | |
| InvoiceDate / DueDate | DATE | |
| TotalAmount | DECIMAL(18,2) | sum of lines, cached |
| BalanceAmount | DECIMAL(18,2) | cached running balance |
| Status | NVARCHAR(20) | `OPEN`, `PARTIAL`, `PAID`, `CANCELLED` |
| JournalEntryId | INT FK → JournalEntries NULL | the GL entry this invoice generated (Dr AR / Cr Revenue) |

`StudentInvoiceLines`: `StudentInvoiceLineId` PK, `StudentInvoiceId` FK, `FeeTypeId` FK, `Description`, `Amount`.

### 6.6 `StudentPayments` (official receipts) / `StudentPaymentAllocations`
| Column | Type | Notes |
|---|---|---|
| StudentPaymentId | INT IDENTITY PK | |
| StudentId | INT FK → Students | |
| PaymentDate | DATETIME | |
| PaymentMethod | NVARCHAR(20) | `CASH`, `CHECK`, `BANK_TRANSFER`, `ONLINE` |
| ReferenceNumber | NVARCHAR(50) NULL | OR number, check number, transaction ID |
| Amount | DECIMAL(18,2) | |
| CashierUserId | INT FK → Users | |
| BankAccountId | INT FK → BankAccounts NULL | populated for non-cash payments |
| Status | NVARCHAR(20) | `POSTED`, `VOIDED` |
| JournalEntryId | INT FK → JournalEntries NULL | Dr Cash/Bank / Cr AR |

`StudentPaymentAllocations`: `StudentPaymentAllocationId` PK, `StudentPaymentId` FK, `StudentInvoiceId` FK, `AllocatedAmount` — lets one payment settle multiple invoices, or a partial invoice.

### 6.7 `ScholarshipTypes` / `StudentScholarships`
| Table | Key columns |
|---|---|
| `ScholarshipTypes` | ScholarshipTypeId PK, ScholarshipName, DiscountPercent NULL, DiscountAmount NULL, ContraRevenueAccountId FK |
| `StudentScholarships` | StudentScholarshipId PK, StudentId FK, ScholarshipTypeId FK, AcademicTermId FK, ApprovedBy, ApprovedDate |

**Business rules:**
- An invoice's `BalanceAmount` only changes through posted `StudentPaymentAllocations` or an approved credit memo (add a `CreditMemos` table later if needed) — never edited directly.
- Voiding a `StudentPayment` must reverse its allocations and generate a reversing journal entry, not delete the row.

---

## 7. Module: Accounts Payable

### 7.1 `Vendors`
| Column | Type | Notes |
|---|---|---|
| VendorId | INT IDENTITY PK | |
| VendorCode | NVARCHAR(20) UNIQUE | |
| VendorName | NVARCHAR(200) | |
| TIN | NVARCHAR(20) NULL | |
| ContactPerson / Phone / Email / Address | NVARCHAR | |
| PaymentTermsDays | INT DEFAULT 30 | |
| DefaultExpenseAccountId | INT FK → ChartOfAccounts NULL | |
| IsActive | BIT | |

### 7.2 `PurchaseOrders` / `PurchaseOrderLines`
| Column | Type | Notes |
|---|---|---|
| PurchaseOrderId | INT IDENTITY PK | |
| PONumber | NVARCHAR(30) UNIQUE | |
| VendorId | INT FK → Vendors | |
| DepartmentId | INT FK → Departments | requesting office |
| OrderDate / ExpectedDeliveryDate | DATE | |
| Status | NVARCHAR(20) | `DRAFT`, `APPROVED`, `PARTIALLY_RECEIVED`, `CLOSED`, `CANCELLED` |
| TotalAmount | DECIMAL(18,2) | cached |
| ApprovedBy / ApprovedDate | NVARCHAR(100) / DATETIME NULL | |

`PurchaseOrderLines`: `POLineId` PK, `PurchaseOrderId` FK, `AccountId` FK, `Description`, `Quantity`, `UnitPrice`, `LineTotal`.

### 7.3 `VendorInvoices` (bills) / `VendorInvoiceLines`
| Column | Type | Notes |
|---|---|---|
| VendorInvoiceId | INT IDENTITY PK | |
| VendorId | INT FK → Vendors | |
| PurchaseOrderId | INT FK → PurchaseOrders NULL | matched PO if any |
| VendorInvoiceNumber | NVARCHAR(50) | vendor's own invoice number |
| InvoiceDate / DueDate | DATE | |
| TotalAmount / BalanceAmount | DECIMAL(18,2) | |
| Status | NVARCHAR(20) | `PENDING_APPROVAL`, `APPROVED`, `PARTIALLY_PAID`, `PAID`, `DISPUTED` |
| JournalEntryId | INT FK → JournalEntries NULL | Dr Expense / Cr AP |

`VendorInvoiceLines`: `VendorInvoiceLineId` PK, `VendorInvoiceId` FK, `AccountId` FK, `DepartmentId` FK, `Description`, `Amount`.

### 7.4 `VendorPayments` / `VendorPaymentAllocations`
| Column | Type | Notes |
|---|---|---|
| VendorPaymentId | INT IDENTITY PK | |
| VendorId | INT FK → Vendors | |
| PaymentDate | DATE | |
| PaymentMethod | NVARCHAR(20) | `CHECK`, `BANK_TRANSFER`, `CASH` |
| BankAccountId | INT FK → BankAccounts | |
| CheckNumber | NVARCHAR(30) NULL | |
| Amount | DECIMAL(18,2) | |
| Status | NVARCHAR(20) | `POSTED`, `VOIDED` |
| JournalEntryId | INT FK → JournalEntries NULL | Dr AP / Cr Cash-Bank |

`VendorPaymentAllocations`: `VendorPaymentAllocationId` PK, `VendorPaymentId` FK, `VendorInvoiceId` FK, `AllocatedAmount`.

**Business rules:**
- A `VendorInvoice` can only be paid up to `BalanceAmount`; allocations across multiple invoices in one payment run are expected (e.g., paying a vendor's whole statement at once).
- PO → Invoice matching (3-way match) is optional; `PurchaseOrderId` on `VendorInvoices` is nullable to support invoices with no PO (utilities, subscriptions).

---

## 8. Module: Budgeting

### 8.1 `BudgetHeaders`
| Column | Type | Notes |
|---|---|---|
| BudgetId | INT IDENTITY PK | |
| FiscalYearId | INT FK → FiscalYears | |
| DepartmentId | INT FK → Departments | |
| BudgetName | NVARCHAR(100) | |
| Status | NVARCHAR(20) | `DRAFT`, `SUBMITTED`, `APPROVED`, `LOCKED` |
| TotalBudgetAmount | DECIMAL(18,2) | cached sum of lines |
| ApprovedBy / ApprovedDate | NVARCHAR(100) / DATETIME NULL | |

### 8.2 `BudgetLines`
| Column | Type | Notes |
|---|---|---|
| BudgetLineId | INT IDENTITY PK | |
| BudgetId | INT FK → BudgetHeaders | |
| AccountId | INT FK → ChartOfAccounts | |
| FiscalPeriodId | INT FK → FiscalPeriods NULL | NULL = full-year line, or spread monthly if populated |
| BudgetedAmount | DECIMAL(18,2) | |

**Business rules:**
- Actuals-vs-budget is a reporting join (`BudgetLines` vs `AccountBalances`), not a stored column — avoids sync drift.
- Once `Status = LOCKED`, `BudgetLines` become read-only; changes require a new `BudgetHeaders` revision row (add a `RevisionNumber` column if formal revision tracking is needed).

---

## 9. Module: Fixed Assets

### 9.1 `FixedAssetCategories`
| Column | Type | Notes |
|---|---|---|
| CategoryId | INT IDENTITY PK | |
| CategoryName | NVARCHAR(100) | e.g. `Buildings`, `Computer Equipment` |
| DefaultUsefulLifeYears | INT | |
| DefaultDepreciationMethod | NVARCHAR(20) | `STRAIGHT_LINE`, `DECLINING_BALANCE` |
| AssetAccountId | INT FK → ChartOfAccounts | |
| AccumulatedDepreciationAccountId | INT FK → ChartOfAccounts | |
| DepreciationExpenseAccountId | INT FK → ChartOfAccounts | |

### 9.2 `FixedAssets`
| Column | Type | Notes |
|---|---|---|
| AssetId | INT IDENTITY PK | |
| AssetCode | NVARCHAR(30) UNIQUE | tag/barcode number |
| AssetName | NVARCHAR(200) | |
| CategoryId | INT FK → FixedAssetCategories | |
| DepartmentId | INT FK → Departments | custodian office |
| AcquisitionDate | DATE | |
| AcquisitionCost | DECIMAL(18,2) | |
| SalvageValue | DECIMAL(18,2) DEFAULT 0 | |
| UsefulLifeYears | INT | |
| DepreciationMethod | NVARCHAR(20) | |
| Status | NVARCHAR(20) | `ACTIVE`, `FULLY_DEPRECIATED`, `DISPOSED` |
| LocationDescription | NVARCHAR(200) NULL | |

### 9.3 `DepreciationEntries`
| Column | Type | Notes |
|---|---|---|
| DepreciationEntryId | INT IDENTITY PK | |
| AssetId | INT FK → FixedAssets | |
| FiscalPeriodId | INT FK → FiscalPeriods | |
| DepreciationAmount | DECIMAL(18,2) | |
| AccumulatedDepreciation | DECIMAL(18,2) | running total as of this period |
| JournalEntryId | INT FK → JournalEntries NULL | Dr Depreciation Expense / Cr Accumulated Depreciation |
| IsPosted | BIT | |

### 9.4 `AssetDisposals`
| Column | Type | Notes |
|---|---|---|
| DisposalId | INT IDENTITY PK | |
| AssetId | INT FK → FixedAssets | |
| DisposalDate | DATE | |
| DisposalMethod | NVARCHAR(20) | `SOLD`, `SCRAPPED`, `DONATED` |
| DisposalProceeds | DECIMAL(18,2) DEFAULT 0 | |
| GainLossAmount | DECIMAL(18,2) | proceeds − net book value at disposal |
| JournalEntryId | INT FK → JournalEntries NULL | |

**Business rules:**
- A period-end job runs depreciation for all `Status = ACTIVE` assets, inserting one `DepreciationEntries` row per asset per fiscal period, then posts a summarized journal entry.
- Disposing an asset requires depreciation to be current through the disposal date before the gain/loss can be calculated correctly.

---

## 10. Module: Cash & Bank Management

### 10.1 `BankAccounts`
| Column | Type | Notes |
|---|---|---|
| BankAccountId | INT IDENTITY PK | |
| AccountName | NVARCHAR(100) | internal label |
| BankName | NVARCHAR(100) | |
| AccountNumber | NVARCHAR(50) | consider encrypting/masking at the application layer |
| ChartAccountId | INT FK → ChartOfAccounts | the GL cash/bank account this represents |
| IsActive | BIT | |

### 10.2 `BankTransactions`
| Column | Type | Notes |
|---|---|---|
| BankTransactionId | BIGINT IDENTITY PK | |
| BankAccountId | INT FK → BankAccounts | |
| TransactionDate | DATE | |
| TransactionType | NVARCHAR(20) | `DEPOSIT`, `WITHDRAWAL`, `TRANSFER`, `BANK_FEE`, `INTEREST` |
| Amount | DECIMAL(18,2) | |
| ReferenceModule | NVARCHAR(20) NULL | `AR`, `AP`, `MANUAL` |
| ReferenceId | NVARCHAR(50) NULL | e.g. StudentPaymentId or VendorPaymentId |
| Description | NVARCHAR(500) NULL | |
| IsReconciled | BIT DEFAULT 0 | |
| JournalEntryId | INT FK → JournalEntries NULL | |

### 10.3 `BankReconciliations` / `BankReconciliationItems`
| Table | Key columns |
|---|---|
| `BankReconciliations` | ReconciliationId PK, BankAccountId FK, StatementDate, StatementEndingBalance, BookBalance, Status (`IN_PROGRESS`/`COMPLETED`), CompletedBy, CompletedDate |
| `BankReconciliationItems` | ReconciliationItemId PK, ReconciliationId FK, BankTransactionId FK, ClearedFlag BIT |

**Business rules:**
- `StudentPayments` and `VendorPayments` that hit a bank account should auto-generate a matching `BankTransactions` row (via trigger or in the same stored procedure) rather than requiring manual re-entry.
- A reconciliation only closes when statement balance minus uncleared items equals the book balance.

---

## 11. Reporting Views (recommended, mirrors the existing `vw_*` pattern)

| View | Purpose |
|---|---|
| `vw_TrialBalance` | Sum of debits/credits per account for a fiscal period |
| `vw_GeneralLedgerDetail` | All `JournalEntryLines` joined to account/department/source |
| `vw_IncomeStatement` | Revenue and Expense accounts for a period range |
| `vw_BalanceSheet` | Asset/Liability/Equity accounts as of a period end |
| `vw_StudentARAging` | Open `StudentInvoices` bucketed by days overdue |
| `vw_VendorAPAging` | Open `VendorInvoices` bucketed by days overdue |
| `vw_BudgetVsActual` | `BudgetLines` joined against `AccountBalances` |
| `vw_FixedAssetRegister` | Assets with cost, accumulated depreciation, and net book value |

---

## 12. Full Foreign-Key Map

```
-- Existing (Phase 1)
Departments             → Departments (self, parent)
Users                   → Departments
UserRoles               → Users, Roles
AuditLogs               → Users
ChartOfAccounts         → AccountTypes, ChartOfAccounts (self, parent), Departments
FiscalPeriods           → FiscalYears
AccountBalances         → ChartOfAccounts, FiscalPeriods

-- New (Phase 2)
JournalEntries          → FiscalPeriods, JournalEntryTypes, JournalEntries (self, reversal)
JournalEntryLines       → JournalEntries, ChartOfAccounts, Departments

AcademicTerms           → FiscalYears
Students                → Departments
FeeTypes                → ChartOfAccounts
FeeStructureLines       → FeeStructures, FeeTypes
StudentInvoices         → Students, AcademicTerms, JournalEntries
StudentInvoiceLines     → StudentInvoices, FeeTypes
StudentPayments         → Students, Users, BankAccounts, JournalEntries
StudentPaymentAllocations → StudentPayments, StudentInvoices
StudentScholarships     → Students, ScholarshipTypes, AcademicTerms

PurchaseOrders          → Vendors, Departments
PurchaseOrderLines      → PurchaseOrders, ChartOfAccounts
VendorInvoices          → Vendors, PurchaseOrders, JournalEntries
VendorInvoiceLines      → VendorInvoices, ChartOfAccounts, Departments
VendorPayments          → Vendors, BankAccounts, JournalEntries
VendorPaymentAllocations → VendorPayments, VendorInvoices

BudgetHeaders           → FiscalYears, Departments
BudgetLines             → BudgetHeaders, ChartOfAccounts, FiscalPeriods

FixedAssets             → FixedAssetCategories, Departments
FixedAssetCategories    → ChartOfAccounts (x3: asset/accum. dep./expense accounts)
DepreciationEntries     → FixedAssets, FiscalPeriods, JournalEntries
AssetDisposals          → FixedAssets, JournalEntries

BankAccounts            → ChartOfAccounts
BankTransactions        → BankAccounts, JournalEntries
BankReconciliations     → BankAccounts
BankReconciliationItems → BankReconciliations, BankTransactions
```

---

## 13. Suggested Build Order

1. **General Ledger** (Module 5) — everything else posts through it, build it first.
2. **Cash & Bank Management** (Module 10) — needed as a payment target for both AR and AP.
3. **Student AR** and **Accounts Payable** (Modules 6 & 7) — can be built in parallel once GL and Banking exist.
4. **Budgeting** (Module 8) — independent, can slot in anytime after the Chart of Accounts.
5. **Fixed Assets** (Module 9) — lowest urgency; typically the last thing a school automates.
6. **Reporting Views** (Module 11) — build incrementally as each module lands.

---

## 14. Open Questions / Assumptions to Confirm

- **Students table**: assumed you don't already have a Registrar/Student Information System to link to. If you do, `Students` here should become a thin reference table or view instead of a duplicate master.
- **Multi-currency**: not included — everything assumes a single reporting currency (PHP, based on the seed data). Say if you need it.
- **Payroll**: intentionally out of scope here — it's usually its own subsystem (Employees, PayrollRuns, Payslips, Deductions) that posts summary journal entries into this GL rather than living inside the accounting schema. Can design separately if needed.
- **Approval workflows**: `Status` columns above assume a single-step approve/reject. If you need multi-level approval (e.g., Dept Head → Finance Manager → Accountant), that typically becomes an `ApprovalSteps` table referencing the header row generically.
