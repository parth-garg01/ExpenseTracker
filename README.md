# Smart Expense Tracker

Monorepo with Flutter mobile app + FastAPI backend as defined in PRD.
Architecture is hybrid offline-first: SQLite local-first app data + backend sync APIs.

## Structure
- `mobile/` Flutter client
- `backend/` FastAPI API + PostgreSQL schema
- `docs/` pipeline and setup notes

## API Keys / Secrets to Add
- `backend/.env`
  - `DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:5432/DBNAME`
  - `SUPABASE_URL=...` (Phase 3)
  - `SUPABASE_SERVICE_ROLE_KEY=...` (Phase 3)
  - `JWT_SECRET=...`
- `mobile/.env`
  - `API_BASE_URL=http://10.0.2.2:8000`
  - `SUPABASE_URL=...` (Phase 3)
  - `SUPABASE_ANON_KEY=...` (Phase 3)

## Run
Backend:
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Mobile:
```bash
cd mobile
flutter pub get
flutter run
```
