# DoctorG — City Doctor Discovery, Booking & Live Queue App

A production-quality MVP for patients in India to discover verified doctors near them, book slots, pay online, and track their live OPD queue in real time so they never waste hours in hospital waiting rooms.

---

## 1. Tech Stack (Fixed)
- **Mobile Client**: Flutter (Dart) — Android first, iOS-ready.
- **State Management**: Riverpod (`flutter_riverpod`).
- **Backend**: Supabase (PostgreSQL 15 + PostGIS, Auth, Realtime, Storage, Edge Functions).
- **Push Notifications**: Firebase Cloud Messaging (**FCM v1 ONLY**). Zero Firestore, Firebase Auth, or Firebase Storage.
- **Payments**: Razorpay (Flutter SDK + Supabase Edge Functions with verified webhook signatures) — **TEST Mode Only**.
- **Maps & Navigation**: Google Maps Flutter SDK, `geolocator`, Google Routes/Directions API.
- **Local Cache**: Hive offline cache + `shared_preferences`.
- **Localization**: English (`en`) + Hindi (`hi`) from day one.

---

## 2. Free-Tier Operational Safety & Limits Guide

DoctorG is architected to run at **$0 / month** during development, testing, and pilot trials supporting **200+ concurrent active users**:

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

## 3. Database Migrations & Seed Data

The database schema is fully managed under `/supabase/migrations/`:
1. `20260930000001_core_schema.sql`: 18 tables, custom enums (`user_role`, `appointment_status`, `payment_status`), foreign keys, and auth trigger.
2. `20260930000002_postgis_and_views.sql`: PostGIS spatial GIST index on `hospitals.location`, spatial RPC `get_nearby_hospitals`, symptom-to-specialization lookup table, and Bayesian ranking view (`doctor_ranking_view`).
3. `20260930000003_rls_policies.sql`: Complete Row Level Security policies guaranteeing patient privacy and medical data confidentiality under India's DPDP Act.
4. `seed.sql`: Realistic dataset for Bengaluru featuring 5 major hospitals (Manipal, Apollo, Fortis, Aster CMI, Narayana Health) and 20 verified doctors with schedules, slots, and completed appointment reviews.

### Running Migrations Locally / on Supabase Cloud
```bash
# Apply migrations using Supabase CLI
supabase db push

# Or apply directly in the Supabase Cloud SQL Editor in order:
# 1. supabase/migrations/20260930000001_core_schema.sql
# 2. supabase/migrations/20260930000002_postgis_and_views.sql
# 3. supabase/migrations/20260930000003_rls_policies.sql
# 4. supabase/seed.sql
```

---

## 4. Setup & Credentials Checklist

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

## 5. Security & DPDP Compliance
- **Zero secrets in client code**: Payment verification is conducted strictly in Supabase Edge Functions via HMAC-SHA256 signature verification.
- **Medical Disclaimer**: DoctorG explicitly disclaims diagnostic liability across onboarding, booking, and app headers.
- **India DPDP Act**: Appointments and medical records are constrained by RLS to only the consulting doctor and the patient.