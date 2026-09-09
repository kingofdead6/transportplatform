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
| Shipper | +213500000002   | OTP login (check console) |
| Carrier | +213500000003   | OTP login |
| Driver  | +213500000004   | OTP login |

## Auth

- `POST /api/auth/request-otp` `{ phone }` → sends OTP (dev mode returns `devCode` in response)
- `POST /api/auth/verify-otp` `{ phone, code, role }` → logs in or creates account, returns JWT
- `POST /api/auth/login` `{ phone, password }` → admin/password login
- `GET /api/auth/me` → current user

## Main resources

- `/api/trips` — full trip lifecycle (create, publish, offers, assign, driver assignment, status updates, tracking ping, POD confirmation, review, incidents, reassignment, return-load matching)
- `/api/trips/:id/documents/*` — bon de transport/livraison, POD upload, goods photos
- `/api/invoices` — issue, record payment, overdue list, reminders
- `/api/disputes` — open, message, resolve
- `/api/reports` — margin report, period summary
- `/api/settings` — platform settings (commission, VAT, return-load radius, reference prices)
- `/api/users`, `/api/vehicles` — profiles, drivers, fleet, document expiry alerts
- `/api/audit` — admin audit trail

Real-time: Socket.IO namespace, JWT-authenticated, rooms `user:<id>` for notifications and `trip:<id>` for live GPS tracking.
