# Prosim Planat — Backend API

Node.js/Express + MongoDB + Cloudinary backend for the Prosim Planat transport & logistics platform.

## Setup

```bash
cd backend
npm install
cp .env.example .env   # fill in MONGO_URI, JWT_SECRET, CLOUDINARY_*
npm run seed            # creates admin/shipper/carrier/driver demo accounts + 1 sample trip
npm run dev              # starts on http://localhost:5000
```

## Demo accounts (after `npm run seed`)

| Role    | Phone           | Password  |
|---------|-----------------|-----------|
| Admin   | +213500000001   | admin123  |
| Shipper | +213500000002   | demo123   |
| Carrier | +213500000003   | demo123   |
| Driver  | +213500000004   | demo123   |

All roles sign in with phone + password. (The OTP endpoints still exist but the
app does not use them; a seeded account without a password could never log in.)

## Auth

- `POST /api/auth/request-otp` `{ phone }` → sends OTP (dev mode returns `devCode` in response)
- `POST /api/auth/verify-otp` `{ phone, code, role }` → logs in or creates account, returns JWT
- `POST /api/auth/login` `{ phone, password }` → admin/password login
- `GET /api/auth/me` → current user

## Main resources

- `/api/trips` — full trip lifecycle (create, publish, offers, **fixed-price accept**,
  assign, driver assignment, status updates, tracking ping, POD confirmation, review,
  incidents, reassignment, **cancellation**, return-load matching)
- `/api/trips/:id/documents/*` — bon de transport/livraison, POD upload, goods photos
- `/api/invoices` — issue, record payment, overdue list, reminders
- `/api/disputes` — open, message, resolve
- `/api/reports` — margin report, period summary
- `/api/settings` — platform settings (commission, VAT, return-load radius, reference prices)
- `/api/users`, `/api/vehicles` — profiles, drivers, fleet, document expiry alerts,
  `PUT /api/users/me/password`, and the admin lookups `GET /api/users/carriers` /
  `GET /api/users/carriers/:id/drivers` used by the assignment pickers
- `/api/audit` — admin audit trail

Real-time: Socket.IO namespace, JWT-authenticated, rooms `user:<id>` for notifications and `trip:<id>` for live GPS tracking.


## Tests

```bash
npm run test:e2e
```

Runs the API end to end against an in-memory MongoDB (43 checks): registration and
login, the fixed-price and bidding flows, driver assignment and tenancy isolation,
the driver mission lifecycle, POD/review/invoicing arithmetic, and the
authorization boundaries between roles.

## Key endpoints added

| Method | Route | Purpose |
|--------|-------|---------|
| PUT | `/api/trips/:id/accept` | Carrier takes a fixed-price load (guarded against double-claim) |
| PUT | `/api/trips/:id/cancel` | Shipper (pre-assignment) or admin cancels a trip |
| PUT | `/api/users/me/password` | Set/change own password |
| GET | `/api/users/carriers` | Carrier lookup for admin assignment |
| GET | `/api/users/carriers/:id/drivers` | That carrier's drivers |
| GET | `/api/invoices/:id` | Single invoice (owner or admin only) |
| GET | `/api/disputes/:id` | Single dispute (participants only) |
