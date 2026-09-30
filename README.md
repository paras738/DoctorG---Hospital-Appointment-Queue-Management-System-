# DoctorG — City Doctor Discovery, Booking & Live Queue App

A production-quality MVP for patients in India to discover verified doctors near them, book slots, pay online, and track their live OPD queue in real time so they never waste hours in hospital waiting rooms.

---

## 1. Tech Stack (Fixed)
- **Mobile Client**: Flutter (Dart) — Android first, iOS-ready.
- **State Management**: Riverpod (`flutter_riverpod`).
- **Backend**: Supabase (PostgreSQL 15 + PostGIS, Auth, Realtime, Storage, Edge Functions).
- **Push Notifications**: Firebase Cloud Messaging (**FCM v1 ONLY**). Zero Firestore, Firebase Auth, or Firebase Storage.
- **Payments**: Razorpay (Flutter SDK + Supabase Edge Functions with verified HMAC-SHA256 webhook signatures) — **TEST Mode Only**.
- **Maps & Navigation**: Google Maps Flutter SDK, `geolocator`, Google Routes/Directions API with Hive offline route caching.
- **Local Cache**: Hive offline cache + `shared_preferences`.
- **Localization**: English (`en`) + Hindi (`hi`) bilingual support.
- **Performance & Load Testing**: Grafana k6 (500 concurrent Virtual Users load suite).

---

## 2. Complete Phase Architecture Breakdown

| Phase | Branch | Core Features Delivered |
| :--- | :--- | :--- |
| **Phase 1** | `feature/phase-1-setup-auth-db-schema` | Supabase Core Schema (18 tables), PostGIS, RLS policies, Auth repository, Seed data for Bengaluru, Hive cache, Design System, Localization foundation (`en`/`hi`). |
| **Phase 2** | `feature/phase-2-doctor-directory-search-ranking` | Doctor Directory Screen, Bayesian ranking view (`doctor_ranking_view`), specialization chips, symptom-to-specialization auto-resolution, Doctor Profile view. |
| **Phase 3** | `feature/phase-3-maps-nearby-hospitals` | Google Maps nearby hospitals integration, PostGIS `get_nearby_hospitals` RPC, local Haversine distance calculations (0 API cost), Hive polyline caching ($\ge 200\text{ m}$ threshold). |
| **Phase 4** | `feature/phase-4-appointment-booking-slot-locking` | Multi-step booking flow, 5-minute optimistic slot locking, family member selection, double-booking prevention, "My Appointments" screen with cancel/reschedule. |
| **Phase 5** | `feature/phase-5-live-queue-realtime-doctor-dashboard` | Scoped Supabase Realtime live queue tracking, estimated wait time, dynamic token state transitions, Doctor OPD Dashboard with one-tap "Call Next", "Mark Done", "No Show". |
| **Phase 6** | `feature/phase-6-razorpay-payments-edge-functions` | Razorpay test mode integration, Supabase Edge Functions (`create-razorpay-order`, `razorpay-webhook`), HMAC-SHA256 signature verification, PDF-ready payment receipt sheet. |
| **Phase 7** | `feature/phase-7-fcm-notifications-reminders-alerts` | FCM HTTP v1 push notifications via Supabase Edge Function (`send-fcm-notification`), queue progress alerts ("You are next"), appointment reminders, in-app notification center. |
| **Phase 8** | `feature/phase-8-reviews-admin-verification-localization-polish` | Verified patient reviews (5-star + quick tags), doctor registration & admin verification panel (`/admin`), dynamic English/Hindi language toggle (`LocaleNotifier`). |
| **Phase 9** | `feature/phase-9-k6-load-testing-free-tier-verification` | k6 500-VU load test suite, free-tier limits verification report, complete architecture documentation, unit test validation. |

---

## 3. Free-Tier Operational Safety & Limits Guide

DoctorG is architected to run at **$0 / month** during development, testing, and pilot trials supporting **200+ concurrent active users**. For complete quota audits, see [`docs/free_tier_limits_verification.md`](docs/free_tier_limits_verification.md):

| Service | Free Tier Limit | DoctorG Built-in Enforcement |
| :--- | :--- | :--- |
| **Supabase Realtime** | 200 concurrent connections | **Ephemeral Scoped Subscriptions**: Realtime connections are established **only** when a user actively views their Live Queue screen or a doctor opens their OPD dashboard. Subscribed *only* to `queue_state:doctor_id=eq.{id}`. Immediately unsubscribed on screen dispose or when the app enters the background. |
| **Supabase Database** | 500 MB database | Lean normalized tables, numeric IDs, PostGIS geography point indexing, automated purge of stale slots. |
| **Supabase Storage** | 1 GB file storage | Client-side image compression before upload (max ~200 KB, 800x800 webp/jpeg). Avatars cached locally in Hive. |
| **Google Maps API** | $200 free monthly credit | **Haversine straight-line distance** on all directory cards and listings (zero API cost). **Routes/Directions API called ONLY upon tapping a hospital card**; polyline is cached locally and only re-fetched if patient location shifts $\ge 200\text{ m}$. |
| **Authentication** | Free tier SMS limits | **Email/Password & Google Sign-In** first (zero SMS costs). Auth layer is built around a pluggable `AuthRepository` with phone OTP methods ready to be switched on with zero consumer code changes. |
| **Push Notifications** | FCM v1 is 100% free | Sent via Supabase Edge Function using FCM v1 HTTP API with Google Service Account credentials. |

> **When to upgrade Supabase to Pro ($25/mo):**
> - When your concurrent live queue viewers exceed 180 connections.
> - When database size approaches 450 MB (e.g. >50,000 completed appointments).
> - When you want automated daily database backups and zero project pausing.

---

## 4. Database Migrations & Seed Data

The database schema is fully managed under `/supabase/migrations/`:
1. `20260930000001_core_schema.sql`: 18 tables, custom enums (`user_role`, `appointment_status`, `payment_status`), foreign keys, and auth trigger.
2. `20260930000002_postgis_and_views.sql`: PostGIS spatial GIST index on `hospitals.location`, spatial RPC `get_nearby_hospitals`, symptom-to-specialization lookup table, and Bayesian ranking view (`doctor_ranking_view`).
3. `20260930000003_rls_policies.sql`: Complete Row Level Security policies guaranteeing patient privacy and medical data confidentiality under India's DPDP Act.
4. `20260930000004_notifications_and_tokens.sql`: Device push tokens, notifications history, RLS policies, and index optimization.
5. `seed.sql`: Realistic dataset for Bengaluru featuring 5 major hospitals (Manipal, Apollo, Fortis, Aster CMI, Narayana Health) and 20 verified doctors with schedules, slots, and completed appointment reviews.

### Running Migrations Locally / on Supabase Cloud
```bash
# Apply migrations using Supabase CLI
supabase db push

# Or apply directly in the Supabase Cloud SQL Editor in order:
# 1. supabase/migrations/20260930000001_core_schema.sql
# 2. supabase/migrations/20260930000002_postgis_and_views.sql
# 3. supabase/migrations/20260930000003_rls_policies.sql
# 4. supabase/migrations/20260930000004_notifications_and_tokens.sql
# 5. supabase/seed.sql
```

---

## 5. Supabase Edge Functions

DoctorG uses Deno-based Supabase Edge Functions to ensure sensitive operations and secrets never touch the mobile client:

| Edge Function | Path | Responsibility |
| :--- | :--- | :--- |
| **`create-razorpay-order`** | `supabase/functions/create-razorpay-order/` | Creates Razorpay order via REST API using server-side `RAZORPAY_KEY_SECRET`. |
| **`razorpay-webhook`** | `supabase/functions/razorpay-webhook/` | Verifies `x-razorpay-signature` via HMAC-SHA256, atomically updates appointment and payment status. |
| **`send-fcm-notification`** | `supabase/functions/send-fcm-notification/` | Dispatches push notifications via FCM HTTP v1 using Google Service Account credentials. |

### Deploying Edge Functions
```bash
supabase functions deploy create-razorpay-order
supabase functions deploy razorpay-webhook --no-verify-jwt
supabase functions deploy send-fcm-notification
```

---

## 6. Performance & Load Testing (k6)

A complete load testing suite is provided in `load_tests/k6_doctorg_load_test.js` to simulate **500 concurrent Virtual Users (VUs)**:

### Test Scenarios Covered
1. **Doctor Directory Browsing & Bayesian Ranking** (`/rest/v1/doctor_ranking_view`)
2. **PostGIS Proximity Search** (`/rest/v1/rpc/get_nearby_hospitals`)
3. **Doctor Schedule & Slot Availability** (`/rest/v1/doctor_schedules`)
4. **Live OPD Queue Polling & Token Tracking** (`/rest/v1/queue_state`)
5. **Verified Patient Reviews Retrieval** (`/rest/v1/reviews`)

### Running the Load Test
```bash
# Install k6 (via winget, choco, or brew)
winget install k6 --source winget

# Execute test against local or remote Supabase instance
k6 run -e SUPABASE_URL=https://your-project.supabase.co -e SUPABASE_ANON_KEY=your-anon-key load_tests/k6_doctorg_load_test.js
```

### SLA & Performance Thresholds
- `http_req_duration`: $p_{95} < 500\text{ ms}$, $p_{99} < 1000\text{ ms}$
- `http_req_failed`: $< 1.0\%$
- `live_queue_duration_ms`: $p_{95} < 250\text{ ms}$

---

## 7. Setup & Credentials Checklist

Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

| Component | Status | Required Credentials |
| :--- | :--- | :--- |
| **Supabase URL & Anon Key** | Ready | `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Supabase Project Settings -> API. |
| **Google Maps API Key** | Ready | `GOOGLE_MAPS_API_KEY` enabled for Maps SDK for Android/iOS & Directions API. |
| **Razorpay Test Mode** | Ready | `RAZORPAY_KEY_ID` (starts with `rzp_test_`). Secret configured only in Supabase Edge Functions. |
| **Firebase Cloud Messaging** | Ready | `google-services.json` (Android) and `GoogleService-Info.plist` (iOS). |
| **Phone OTP** | Pluggable | Tested via mock/email; requires Twilio/MSG91 configured in Supabase Auth when upgrading. |

---

## 8. Running Quality Checks & Tests

```bash
# Format all Dart files across lib and test
dart format lib test

# Run all unit tests
flutter test test/unit/
```

### Verified Test Suite (10 Test Suites, 35+ Unit Tests):
- `test/unit/booking_test.dart`
- `test/unit/distance_calculator_test.dart`
- `test/unit/doctor_ranking_test.dart`
- `test/unit/hospital_model_test.dart`
- `test/unit/live_queue_test.dart`
- `test/unit/notification_test.dart`
- `test/unit/payment_test.dart`
- `test/unit/reviews_and_admin_test.dart`
- `test/unit/user_profile_test.dart`
- `test/unit/load_test_config_test.dart`

---

## 9. Security & DPDP Compliance
- **Zero secrets in client code**: Payment verification is conducted strictly in Supabase Edge Functions via HMAC-SHA256 signature verification.
- **Medical Disclaimer**: DoctorG explicitly disclaims diagnostic liability across onboarding, booking, and app headers.
- **India DPDP Act**: Appointments and medical records are constrained by RLS to only the consulting doctor and the patient.