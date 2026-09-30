-- DoctorG: PostgreSQL + PostGIS Views & Stored Procedures
-- Migration 02: Bayesian Ranking View, PostGIS Proximity RPC, and Symptom Mapping

-- 1. BAYESIAN RANKING VIEW (doctor_ranking_view)
CREATE OR REPLACE VIEW public.doctor_ranking_view AS
WITH global_stats AS (
    SELECT 
        COALESCE(AVG(rating), 4.0)::numeric AS global_avg_rating
    FROM public.reviews
),
doctor_stats AS (
    SELECT 
        d.id AS doctor_id,
        p.full_name,
        d.registration_number,
        d.specialization,
        d.experience_years,
        d.consultation_fee,
        d.languages,
        d.photo_url,
        d.bio,
        d.is_verified,
        d.is_available_today,
        d.is_available_now,
        d.avg_consultation_minutes,
        COUNT(r.id)::numeric AS review_count,
        COALESCE(AVG(r.rating), 0)::numeric AS avg_rating
    FROM public.doctors d
    JOIN public.profiles p ON p.id = d.id
    LEFT JOIN public.reviews r ON r.doctor_id = d.id
    GROUP BY d.id, p.full_name
)
SELECT 
    ds.doctor_id,
    ds.full_name,
    ds.registration_number,
    ds.specialization,
    ds.experience_years,
    ds.consultation_fee,
    ds.languages,
    ds.photo_url,
    ds.bio,
    ds.is_verified,
    ds.is_available_today,
    ds.is_available_now,
    ds.avg_consultation_minutes,
    ds.review_count::int AS review_count,
    ROUND(ds.avg_rating, 2) AS avg_rating,
    -- Bayesian Weighted Score: (v/(v+m))*R + (m/(v+m))*C + (0.25 if available now)
    -- m = 10
    ROUND(
        (
            ((ds.review_count / (ds.review_count + 10.0)) * ds.avg_rating) +
            ((10.0 / (ds.review_count + 10.0)) * gs.global_avg_rating) +
            (CASE WHEN ds.is_available_now THEN 0.25 ELSE 0.0 END)
        ),
        3
    ) AS bayesian_score,
    -- Top rated badge: 4.5+ average with 50+ reviews
    (ds.avg_rating >= 4.5 AND ds.review_count >= 50) AS is_top_rated
FROM doctor_stats ds
CROSS JOIN global_stats gs
WHERE ds.is_verified = true;

-- 2. NEARBY HOSPITALS RPC (PostGIS with GIST Index)
CREATE OR REPLACE FUNCTION public.get_nearby_hospitals(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters DOUBLE PRECISION DEFAULT 10000.0
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    address TEXT,
    city TEXT,
    pincode VARCHAR(6),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    emergency_available BOOLEAN,
    doctors_today_count BIGINT
) 
LANGUAGE sql 
STABLE
AS $$
    SELECT 
        h.id,
        h.name,
        h.address,
        h.city,
        h.pincode,
        ST_Y(h.location::geometry) AS latitude,
        ST_X(h.location::geometry) AS longitude,
        ROUND(ST_Distance(h.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography)::numeric, 1)::double precision AS distance_meters,
        h.emergency_available,
        COUNT(DISTINCT dh.doctor_id) AS doctors_today_count
    FROM public.hospitals h
    LEFT JOIN public.doctor_hospitals dh ON dh.hospital_id = h.id
    LEFT JOIN public.doctors d ON d.id = dh.doctor_id AND d.is_available_today = true AND d.is_verified = true
    WHERE ST_DWithin(h.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
    GROUP BY h.id, h.name, h.address, h.city, h.pincode, h.location, h.emergency_available
    ORDER BY distance_meters ASC;
$$;

-- 3. SYMPTOM TO SPECIALIZATION MAPPING TABLE & FUNCTION
CREATE TABLE IF NOT EXISTS public.symptom_mappings (
    id SERIAL PRIMARY KEY,
    symptom TEXT NOT NULL UNIQUE,
    specialization TEXT NOT NULL
);

INSERT INTO public.symptom_mappings (symptom, specialization) VALUES
    ('chest pain', 'Cardiologist'),
    ('heart palpitations', 'Cardiologist'),
    ('shortness of breath', 'Cardiologist'),
    ('high blood pressure', 'Cardiologist'),
    ('skin rash', 'Dermatologist'),
    ('acne', 'Dermatologist'),
    ('hair loss', 'Dermatologist'),
    ('itching', 'Dermatologist'),
    ('eczema', 'Dermatologist'),
    ('fever', 'General Physician'),
    ('cough', 'General Physician'),
    ('cold', 'General Physician'),
    ('body ache', 'General Physician'),
    ('weakness', 'General Physician'),
    ('ear pain', 'ENT Specialist'),
    ('hearing loss', 'ENT Specialist'),
    ('sore throat', 'ENT Specialist'),
    ('sinus', 'ENT Specialist'),
    ('joint pain', 'Orthopedic'),
    ('knee pain', 'Orthopedic'),
    ('back pain', 'Orthopedic'),
    ('fracture', 'Orthopedic'),
    ('toothache', 'Dentist'),
    ('bleeding gums', 'Dentist'),
    ('cavity', 'Dentist'),
    ('child fever', 'Pediatrician'),
    ('baby vaccination', 'Pediatrician'),
    ('child growth', 'Pediatrician'),
    ('pregnancy care', 'Gynecologist'),
    ('menstrual pain', 'Gynecologist'),
    ('pcod', 'Gynecologist'),
    ('headache', 'Neurologist'),
    ('migraine', 'Neurologist'),
    ('dizziness', 'Neurologist'),
    ('anxiety', 'Psychiatrist'),
    ('depression', 'Psychiatrist'),
    ('sleep disorder', 'Psychiatrist'),
    ('blurred vision', 'Ophthalmologist'),
    ('eye irritation', 'Ophthalmologist'),
    ('stomach pain', 'Gastroenterologist'),
    ('acidity', 'Gastroenterologist'),
    ('constipation', 'Gastroenterologist')
ON CONFLICT (symptom) DO NOTHING;

-- 4. FUNCTION TO SEARCH DOCTORS BY QUERY (Symptom, Specialization, or Doctor Name)
CREATE OR REPLACE FUNCTION public.search_doctors(
    search_query TEXT,
    target_city TEXT DEFAULT NULL
)
RETURNS TABLE (
    doctor_id UUID,
    full_name TEXT,
    specialization TEXT,
    consultation_fee NUMERIC,
    avg_rating NUMERIC,
    review_count INT,
    bayesian_score NUMERIC,
    is_top_rated BOOLEAN,
    is_available_today BOOLEAN,
    is_available_now BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
    WITH matched_specialization AS (
        SELECT specialization 
        FROM public.symptom_mappings 
        WHERE symptom ILIKE '%' || TRIM(search_query) || '%'
        LIMIT 1
    )
    SELECT 
        v.doctor_id,
        v.full_name,
        v.specialization,
        v.consultation_fee,
        v.avg_rating,
        v.review_count,
        v.bayesian_score,
        v.is_top_rated,
        v.is_available_today,
        v.is_available_now
    FROM public.doctor_ranking_view v
    WHERE (
        v.full_name ILIKE '%' || TRIM(search_query) || '%'
        OR v.specialization ILIKE '%' || TRIM(search_query) || '%'
        OR v.specialization IN (SELECT specialization FROM matched_specialization)
    )
    ORDER BY v.bayesian_score DESC;
$$;
