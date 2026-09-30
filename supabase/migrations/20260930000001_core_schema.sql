-- DoctorG: PostgreSQL + PostGIS Core Schema
-- Migration 01: Core Extensions, Enums, Tables & Indexes

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. CUSTOM ENUMS
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('patient', 'doctor', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE appointment_status AS ENUM (
        'pending_payment',
        'confirmed',
        'in_progress',
        'completed',
        'cancelled',
        'no_show'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE booking_payment_type AS ENUM ('online_full', 'clinic_pay');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE queue_status AS ENUM ('active', 'paused', 'ended');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE token_status AS ENUM ('waiting', 'called', 'with_doctor', 'completed', 'skipped');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('created', 'captured', 'failed', 'refunded');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_mode AS ENUM ('full', 'booking_fee');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    phone TEXT,
    full_name TEXT NOT NULL DEFAULT '',
    role user_role NOT NULL DEFAULT 'patient',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. FAMILY MEMBERS (Patient can book for self or family member)
CREATE TABLE IF NOT EXISTS public.family_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    relationship TEXT NOT NULL,
    age SMALLINT NOT NULL CHECK (age >= 0 AND age <= 130),
    gender VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. HOSPITALS / CLINICS (PostGIS Geography Point for proximity)
CREATE TABLE IF NOT EXISTS public.hospitals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    pincode VARCHAR(6) NOT NULL,
    location GEOGRAPHY(Point, 4326) NOT NULL,
    phone TEXT,
    emergency_available BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_hospitals_location ON public.hospitals USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_hospitals_city ON public.hospitals (city);

-- 6. DOCTORS
CREATE TABLE IF NOT EXISTS public.doctors (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    registration_number TEXT UNIQUE NOT NULL,
    specialization TEXT NOT NULL,
    experience_years SMALLINT NOT NULL DEFAULT 0,
    consultation_fee NUMERIC(10, 2) NOT NULL DEFAULT 500.00,
    languages TEXT[] NOT NULL DEFAULT ARRAY['English', 'Hindi'],
    photo_url TEXT,
    bio TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    is_available_today BOOLEAN NOT NULL DEFAULT true,
    is_available_now BOOLEAN NOT NULL DEFAULT false,
    avg_consultation_minutes SMALLINT NOT NULL DEFAULT 15,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_doctors_specialization ON public.doctors (specialization);
CREATE INDEX IF NOT EXISTS idx_doctors_verified ON public.doctors (is_verified);

-- 7. DOCTOR-HOSPITAL AFFILIATIONS
CREATE TABLE IF NOT EXISTS public.doctor_hospitals (
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    hospital_id UUID NOT NULL REFERENCES public.hospitals(id) ON DELETE CASCADE,
    room_number TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (doctor_id, hospital_id)
);

-- 8. SCHEDULES
CREATE TABLE IF NOT EXISTS public.schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sun, 6=Sat
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_duration_minutes SMALLINT NOT NULL DEFAULT 15,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_schedules_doctor ON public.schedules (doctor_id, day_of_week);

-- 9. SLOTS (Double-booking protection)
CREATE TABLE IF NOT EXISTS public.slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    slot_date DATE NOT NULL,
    slot_start TIMESTAMPTZ NOT NULL,
    slot_end TIMESTAMPTZ NOT NULL,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    locked_until TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'booked', 'blocked')),
    CONSTRAINT unique_doctor_slot UNIQUE (doctor_id, slot_start)
);

CREATE INDEX IF NOT EXISTS idx_slots_doctor_date ON public.slots (doctor_id, slot_date, status);

-- 10. APPOINTMENTS
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id),
    patient_id UUID NOT NULL REFERENCES public.profiles(id),
    family_member_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
    slot_id UUID NOT NULL REFERENCES public.slots(id),
    appointment_date DATE NOT NULL,
    token_number INT NOT NULL,
    status appointment_status NOT NULL DEFAULT 'pending_payment',
    booking_type booking_payment_type NOT NULL DEFAULT 'online_full',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_appointments_patient ON public.appointments (patient_id, appointment_date);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor ON public.appointments (doctor_id, appointment_date, status);

-- 11. LIVE QUEUE STATE (1 row per doctor per day for high-performance narrow realtime)
CREATE TABLE IF NOT EXISTS public.queue_state (
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    queue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    current_token INT NOT NULL DEFAULT 0,
    last_token INT NOT NULL DEFAULT 0,
    avg_minutes SMALLINT NOT NULL DEFAULT 15,
    delay_minutes SMALLINT NOT NULL DEFAULT 0,
    status queue_status NOT NULL DEFAULT 'active',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (doctor_id, queue_date)
);

-- 12. QUEUE TOKENS
CREATE TABLE IF NOT EXISTS public.queue_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.doctors(id),
    queue_date DATE NOT NULL,
    token_number INT NOT NULL,
    status token_status NOT NULL DEFAULT 'waiting',
    called_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_queue_tokens_doctor_date ON public.queue_tokens (doctor_id, queue_date, token_number);

-- 13. PAYMENTS (Razorpay Test Mode)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
    razorpay_order_id TEXT UNIQUE NOT NULL,
    razorpay_payment_id TEXT,
    razorpay_signature TEXT,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    status payment_status NOT NULL DEFAULT 'created',
    mode payment_mode NOT NULL DEFAULT 'full',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments (razorpay_order_id);

-- 14. REVIEWS (1 verified review per completed appointment)
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID UNIQUE NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.doctors(id),
    patient_id UUID NOT NULL REFERENCES public.profiles(id),
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    doctor_reply TEXT,
    doctor_replied_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_reviews_doctor ON public.reviews (doctor_id, rating);

-- 15. REVIEW REPORTS
CREATE TABLE IF NOT EXISTS public.review_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES public.profiles(id),
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 16. FOLLOWS / FAVORITES
CREATE TABLE IF NOT EXISTS public.follows (
    patient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    notify_on_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (patient_id, doctor_id)
);

-- 17. NOTIFICATION TOKENS (FCM v1 only)
CREATE TABLE IF NOT EXISTS public.notification_tokens (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type VARCHAR(20) NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (user_id, token)
);

-- 18. NOTIFICATION PREFERENCES
CREATE TABLE IF NOT EXISTS public.notification_prefs (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    queue_updates BOOLEAN NOT NULL DEFAULT true,
    slot_reminders BOOLEAN NOT NULL DEFAULT true,
    promotions BOOLEAN NOT NULL DEFAULT false
);

-- 19. PROFILE TRIGGER ON NEW AUTH USER
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        COALESCE((new.raw_user_meta_data->>'role')::user_role, 'patient'::user_role)
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = CASE WHEN profiles.full_name = '' THEN EXCLUDED.full_name ELSE profiles.full_name END;

    INSERT INTO public.notification_prefs (user_id)
    VALUES (new.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
