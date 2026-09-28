# WAWO Hub

WAWO Brand House internal operations platform MVP.

## What is included
- Dashboard with revenue, gross profit, receivables, inventory value and job pipeline
- Inventory and stock adjustments
- Products & pricing library
- Clients
- Quotes
- Orders / jobs
- Production Kanban view
- Expenses
- Revenue Calculator with break-even, target-margin pricing and 3 scenarios
- Reports and CSV export
- Local browser persistence with seeded demo data

## Run
Open `hub/index.html` in a browser, or serve the repository with any static web server.

## Backend
`hub/supabase-schema.sql` contains the PostgreSQL/Supabase data model for the next integration phase. The current MVP intentionally runs locally so the operations and pricing flows can be tested without credentials.
