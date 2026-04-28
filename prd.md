# 📄 Product Requirements Document (PRD)

## Product Name: Smart Expense Tracker

---

# 1. 🎯 Objective

Build a mobile application that automatically tracks user expenses by fetching transaction data (via SMS initially, Account Aggregator APIs later), intelligently classifies vendors, and provides multiple intuitive views, filters, and analytics of financial activity.

---

# 2. ⚠️ Core Constraints (VERY IMPORTANT)

* Direct APIs from banks (e.g., ICICI Bank) or apps (e.g., Google Pay) are NOT accessible.
* MVP MUST use:

  * SMS parsing (Android only)
* Future upgrade:

  * Account Aggregator APIs

---

# 3. 🧩 Core Features

## 3.1 Transaction Fetching

* Parse SMS for:

  * amount
  * debit/credit
  * vendor name
  * date/time
  * UPI reference
* Store raw + processed data

---

## 3.2 Vendor Classification System

* If vendor exists:

  * Auto-map to:

    * shop_name
    * shop_type
* If new vendor:

  * Prompt user:

    * Enter shop name
    * Select shop type (dropdown)
    * Add new type if needed

---

## 3.3 Shop Type System

* Predefined + dynamic creation
* Dropdown UI
* Editable anytime

---

## 3.4 Transaction Metadata

* Optional description field
* Editable anytime

---

## 3.5 Filters & Sorting

* Filter by:

  * Amount > X
  * Date range
  * Vendor
  * Shop type
* Sort by:

  * Amount (asc/desc)
  * Date (latest/oldest)

---

## 3.6 Views

### A. Date-Time View (Primary)

* Group by month
* Show:

  * Total spent (RED)
  * Total received (GREEN)
* Transactions:

  * Red = debit
  * Green = credit
* Editable classification inline

---

### B. Shop Name View

* Group transactions per vendor

---

### C. Shop Type View

* Group by category
* Show totals (red/green)

---

## 3.7 Unclassified Transactions

* Vendor = raw bank name
* Shop type = "Anonymous"
* Highlight as pending classification

---

## 3.8 Editing System

* Edit:

  * shop name
  * shop type
  * description
* Changes propagate to future matches

---

## 3.9 Backup & Restore

* Cloud sync via:

  * Supabase OR Firebase
* Login required
* Reinstall app → auto restore

---

# 4. 🏗️ System Architecture

```
Mobile App (Flutter)
        ↓
Backend API (FastAPI / Node.js)
        ↓
Database (PostgreSQL)
        ↓
Data Sources:
    - SMS Parser (MVP)
    - Account Aggregator APIs (future)
```

---

# 5. ⚙️ Technology Stack

## Frontend

* Flutter

## Backend

* FastAPI (Python) OR Node.js (Express)

## Database

* PostgreSQL

## Cloud

* Supabase / Firebase

## Parsing

* Regex-based SMS parser

---

# 6. 🗄️ Database Schema

### Users

* id
* email

### Transactions

* id
* user_id
* amount
* type (debit/credit)
* vendor_id (nullable)
* raw_vendor_name
* date
* description

### Vendors

* id
* name
* normalized_name
* shop_type_id

### ShopTypes

* id
* name

---

# 7. 🔄 Backend Pipeline

1. SMS received
2. Parse transaction
3. Normalize vendor name
4. Check vendor DB:

   * Exists → auto classify
   * New → mark unclassified
5. Store transaction
6. Trigger UI update

---

# 8. 🎨 UI/UX Design Guidelines

## Design Principles

* Minimal but not boring
* Soft color accents
* Clean cards layout

## Color Scheme

* Red → Expense
* Green → Income
* Yellow → Unclassified

---

## Screens

### 1. Dashboard (Date View)

* Monthly grouping
* Total spent/received
* Transaction list

### 2. Vendor Screen

* List of vendors
* Total per vendor

### 3. Category Screen

* Grouped by shop type

### 4. Add/Edit Transaction Modal

* Edit classification
* Add description

---

# 9. ⚡ Performance Requirements

* Pagination for transactions
* Indexed DB queries (user_id, date)
* Lazy loading
* Cache recent data

---

# 10. 🧪 SANITY CHECK SYSTEM (MANDATORY)

The system MUST run sanity checks after every feature implementation.

## Requirements:

* Display current step:
  Example:

  ```
  [Sanity Check] Step 1/5: Database connection test...
  [Sanity Check] Step 2/5: API endpoint validation...
  ```
* Do NOT skip logs
* Show progress clearly

## Checks:

1. Database connection working
2. CRUD operations valid
3. API endpoints responding
4. UI rendering correctly
5. Data consistency verified

---

# 11. 🔁 GIT COMMIT POLICY (STRICT)

After EVERY feature implementation:

* Commit immediately
* Use clean commit messages:
  Examples:

  * "Add SMS parsing module"
  * "Implement vendor classification logic"
  * "Add transaction filters"

## Rules:

* NO large uncommitted changes
* One feature = one commit
* Avoid vague commit messages

---

# 12. 🚀 DEVELOPMENT PHASES

## Phase 1 (MVP)

* SMS parsing
* Manual classification
* Basic UI

## Phase 2

* Filters + sorting
* Vendor auto-learning

## Phase 3

* Cloud sync + auth

## Phase 4

* Account Aggregator integration

---

# 13. ✅ SUCCESS CRITERIA

* Transactions auto-fetched via SMS
* Vendors auto-classified after first input
* Filters + sorting working
* Monthly summaries accurate
* Data persists after reinstall
* Smooth UI (no lag)

---

# 14. 📌 FINAL NOTE

System must prioritize:

* Reliability
* Simplicity
* Scalability

Avoid over-engineering UI or backend in early phases.
