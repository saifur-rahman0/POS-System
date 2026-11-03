# Retail POS System

A dependable, local-first Point-of-Sale (POS) and inventory system designed for small retail shops in Bangladesh.

---

## Architecture Overview

- **Topology**: One authoritative local PostgreSQL database and one FastAPI service per shop installation. All LAN terminals connect to this local service. Core checkout operates without internet connectivity.
- **Backend**: Python 3.11+, FastAPI, SQLAlchemy 2.x (async), Alembic, Pydantic v2.
- **Frontend**: Flutter desktop (Windows first), Riverpod for state management.
- **Database**: PostgreSQL 16 (with `NUMERIC` for monetary amounts and strict transaction atomicity).

---

## Quick Start (Local Development)

### Prerequisites

- Python 3.11+
- Flutter 3.19+ (with Windows desktop support enabled)
- Docker & Docker Compose (or local PostgreSQL 16)

---

### 1. Environment Configuration

Copy the example environment configuration:

```bash
cp .env.example .env
```

Ensure placeholders are replaced with appropriate values for your environment. Never commit real credentials or private keys.

---

### 2. Start Database & Backend with Docker Compose

To spin up both the local PostgreSQL instance and FastAPI backend:

```bash
docker compose -f infra/docker-compose.dev.yml up -d
```

- Backend API: `http://localhost:8000`
- Interactive API Docs: `http://localhost:8000/docs`
- Health Endpoint: `http://localhost:8000/health` (or `http://localhost:8000/api/v1/health`)

To shut down:

```bash
docker compose -f infra/docker-compose.dev.yml down
```

---

### 3. Running Backend Locally (Without Docker)

#### Setup Virtual Environment

```bash
cd backend
python -m venv .venv

# Windows
.venv\Scripts\activate
# Linux/macOS
source .venv/bin/activate

pip install -r requirements.txt
```

#### Run Database Migrations

```bash
alembic upgrade head
```

#### Start FastAPI Server

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

---

### 4. Running the Flutter Desktop Client

```bash
cd client
flutter pub get
flutter run -d windows
```

---

## Testing & Quality Assurance

### Backend Linting, Typing & Tests

```bash
cd backend

# Lint and formatting checks
ruff check app tests
ruff format --check app tests

# Static type checking
mypy app

# Unit and integration tests with coverage
pytest tests -v --cov=app
```

### Flutter Client Checks

```bash
cd client

# Check formatting
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze

# Widget and unit tests
flutter test
```

---

## Health Check Contract

The `/health` and `/api/v1/health` endpoints verify application and database readiness without exposing internal connection strings or credentials:

```json
{
  "status": "healthy",
  "version": "0.1.0",
  "environment": "development",
  "services": {
    "database": "connected"
  }
}
```

If the database is disconnected, the endpoint returns `503 Service Unavailable` with `"status": "degraded"` and `"database": "disconnected"`.

