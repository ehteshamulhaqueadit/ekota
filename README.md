# Ekota — Merged Project

A full-stack platform for crowdfunded equipment rental. This is the unified repository combining the work of Abrar and Adit.

---

## Project Structure

```
Ekota_Merged/
├── ekota_server/           # Node.js / Express / Prisma backend (port 5001)
├── clients/
│   ├── ekota_admin/        # React + Vite admin dashboard (port 5173)
│   ├── ekota_builder/      # Flutter app for Producers (builders)
│   ├── ekota_public/       # Flutter app for Renters (public users)
│   └── ekota_syndicate/    # Flutter app for Investors (syndicate members)
└── info/                   # Project documentation & API notes
```

---

## What Each Client Does

| Client | Users | Key Features |
|---|---|---|
| `ekota_admin` | Admins | Withdrawal management, payment audit log, warehouse gate pass |
| `ekota_builder` | Producers | List equipment, track funding, KYC verification, manage orders & withdrawals |
| `ekota_public` | Renters | Browse & rent equipment, QR gate pass, live location map, payments, watchlist |
| `ekota_syndicate` | Investors | Invest in listings, vote on rent prices, track portfolio, warehouse management |

---

## Backend Setup

### Prerequisites
- Node.js 20+
- PostgreSQL 15+ **with the PostGIS extension enabled**

### Enable PostGIS
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### Install & Run
```bash
cd ekota_server
cp .env.example .env     # Fill in your real values
npm install
npx prisma generate
npx prisma db push       # Or: npx prisma migrate dev
npm run dev
```

Server runs at `http://localhost:5001`

---

## Admin Dashboard Setup

```bash
cd clients/ekota_admin
npm install
npm run dev
```

Dashboard runs at `http://localhost:5173`

---

## Flutter App Setup (Builder / Public / Syndicate)

Each Flutter app has its own `.env` file for the API base URL.

```bash
cd clients/ekota_builder    # (or ekota_public / ekota_syndicate)
# Create a .env file:
echo "API_BASE_URL=http://10.0.2.2:5001/api" > .env   # Android emulator
# echo "API_BASE_URL=http://localhost:5001/api" > .env  # iOS sim / web
flutter pub get
flutter run
```

---

## Key API Endpoints

| Route | Description |
|---|---|
| `POST /api/auth/signup` | Register (sends OTP verification email) |
| `POST /api/auth/login` | Login |
| `GET /api/auth/me` | Get current user profile |
| `GET /api/listings` | Public listing search/browse |
| `POST /api/listings` | Create a listing (PRODUCER) |
| `GET /api/kyc/profile` | Get KYC status |
| `POST /api/kyc/initiate` | Start Didit KYC session |
| `POST /api/uploads` | Upload images/videos (multipart) |
| `GET /api/payments/*` | SSLCommerz payment flows |
| `GET /api/rentals/*` | Rental lifecycle endpoints |
| `GET /api/investments/*` | Investment endpoints |
| `GET /api/withdrawals/*` | Withdrawal request endpoints |

See `info/` for detailed API documentation.

---

## Environment Variables

See `ekota_server/.env.example` for all required environment variables.
