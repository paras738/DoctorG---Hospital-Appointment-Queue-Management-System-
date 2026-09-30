-- DoctorG: Realistic Seed Data for Bengaluru, India
-- 5 Hospitals, 20 Verified Doctors, Schedules, Slots, Completed Appointments & Reviews

-- 1. HOSPITALS (Bengaluru Coordinates: Longitude, Latitude)
-- Manipal Hospital Old Airport Rd: 77.6517, 12.9592
-- Apollo Hospitals Bannerghatta Rd: 77.5986, 12.8938
-- Fortis Hospital Cunningham Rd: 77.5947, 12.9882
-- Aster CMI Hospital Hebbal: 77.5925, 13.0558
-- Narayana Health City Bommasandra: 77.6917, 12.8183

INSERT INTO public.hospitals (id, name, address, city, pincode, location, phone, emergency_available)
VALUES 
    (
        '10000000-0000-0000-0000-000000000001',
        'Manipal Hospital',
        '98, HAL Old Airport Rd, Kodihalli',
        'Bengaluru',
        '560017',
        ST_SetSRID(ST_MakePoint(77.6517, 12.9592), 4326)::geography,
        '+91 80 2502 4444',
        true
    ),
    (
        '10000000-0000-0000-0000-000000000002',
        'Apollo Hospitals',
        '154/11, Opp. IIMB, Bannerghatta Road',
        'Bengaluru',
        '560076',
        ST_SetSRID(ST_MakePoint(77.5986, 12.8938), 4326)::geography,
        '+91 80 2630 4050',
        true
    ),
    (
        '10000000-0000-0000-0000-000000000003',
        'Fortis Hospital',
        '14, Cunningham Road, Vasanth Nagar',
        'Bengaluru',
        '560052',
        ST_SetSRID(ST_MakePoint(77.5947, 12.9882), 4326)::geography,
        '+91 80 4199 4444',
        true
    ),
    (
        '10000000-0000-0000-0000-000000000004',
        'Aster CMI Hospital',
        'No. 43/42, NH 44, New Airport Rd, Sahakar Nagar, Hebbal',
        'Bengaluru',
        '560092',
        ST_SetSRID(ST_MakePoint(77.5925, 13.0558), 4326)::geography,
        '+91 80 4342 0100',
        true
    ),
    (
        '10000000-0000-0000-0000-000000000005',
        'Narayana Health City',
        '258/A, Bommasandra Industrial Area, Anekal Taluk',
        'Bengaluru',
        '560099',
        ST_SetSRID(ST_MakePoint(77.6917, 12.8183), 4326)::geography,
        '+91 80 7122 2222',
        true
    )
ON CONFLICT (id) DO NOTHING;

-- 2. CREATE DOCTOR USER PROFILES (auth mock IDs for seed)
DO $$
DECLARE
    doc_ids UUID[] := ARRAY[
        '20000000-0000-0000-0000-000000000001'::UUID,
        '20000000-0000-0000-0000-000000000002'::UUID,
        '20000000-0000-0000-0000-000000000003'::UUID,
        '20000000-0000-0000-0000-000000000004'::UUID,
        '20000000-0000-0000-0000-000000000005'::UUID,
        '20000000-0000-0000-0000-000000000006'::UUID,
        '20000000-0000-0000-0000-000000000007'::UUID,
        '20000000-0000-0000-0000-000000000008'::UUID,
        '20000000-0000-0000-0000-000000000009'::UUID,
        '20000000-0000-0000-0000-000000000010'::UUID,
        '20000000-0000-0000-0000-000000000011'::UUID,
        '20000000-0000-0000-0000-000000000012'::UUID,
        '20000000-0000-0000-0000-000000000013'::UUID,
        '20000000-0000-0000-0000-000000000014'::UUID,
        '20000000-0000-0000-0000-000000000015'::UUID,
        '20000000-0000-0000-0000-000000000016'::UUID,
        '20000000-0000-0000-0000-000000000017'::UUID,
        '20000000-0000-0000-0000-000000000018'::UUID,
        '20000000-0000-0000-0000-000000000019'::UUID,
        '20000000-0000-0000-0000-000000000020'::UUID
    ];
    doc_names TEXT[] := ARRAY[
        'Dr. Rajesh Sharma', 'Dr. Sunita Kulkarni', 'Dr. Arvind Menon', 'Dr. Priya Nair', 'Dr. Amit Deshmukh',
        'Dr. Neha Agarwal', 'Dr. Vikram Reddy', 'Dr. Kavita Iyer', 'Dr. Rakesh Verma', 'Dr. Deepa Joshi',
        'Dr. Sanjay Patil', 'Dr. Ananya Mukherjee', 'Dr. Suresh Gowda', 'Dr. Pooja Rao', 'Dr. Karthik Subramanian',
        'Dr. Swati Bhat', 'Dr. Manoj Tiwari', 'Dr. Shruti Sen', 'Dr. Harish Prasad', 'Dr. Meera Nambiar'
    ];
    doc_specs TEXT[] := ARRAY[
        'Cardiologist', 'Dermatologist', 'General Physician', 'Pediatrician', 'Orthopedic',
        'Gynecologist', 'ENT Specialist', 'Neurologist', 'Dentist', 'Psychiatrist',
        'Gastroenterologist', 'Ophthalmologist', 'Cardiologist', 'Dermatologist', 'General Physician',
        'Pediatrician', 'Orthopedic', 'Gynecologist', 'Urologist', 'Endocrinologist'
    ];
    doc_exp INT[] := ARRAY[18, 12, 15, 10, 16, 14, 9, 20, 8, 11, 17, 13, 22, 7, 6, 15, 19, 12, 21, 14];
    doc_fees NUMERIC[] := ARRAY[800, 600, 400, 500, 700, 750, 500, 900, 400, 1000, 850, 550, 950, 500, 350, 600, 800, 700, 900, 750];
    hosp_ids UUID[] := ARRAY[
        '10000000-0000-0000-0000-000000000001'::UUID,
        '10000000-0000-0000-0000-000000000002'::UUID,
        '10000000-0000-0000-0000-000000000003'::UUID,
        '10000000-0000-0000-0000-000000000004'::UUID,
        '10000000-0000-0000-0000-000000000005'::UUID
    ];
    i INT;
BEGIN
    FOR i IN 1..20 LOOP
        -- Insert profile
        INSERT INTO public.profiles (id, email, phone, full_name, role)
        VALUES (
            doc_ids[i],
            'doctor' || i || '@doctorg.in',
            '+9198000000' || LPAD(i::text, 2, '0'),
            doc_names[i],
            'doctor'
        )
        ON CONFLICT (id) DO NOTHING;

        -- Insert doctor record
        INSERT INTO public.doctors (
            id, registration_number, specialization, experience_years, consultation_fee,
            languages, photo_url, bio, is_verified, is_available_today, is_available_now, avg_consultation_minutes
        )
        VALUES (
            doc_ids[i],
            'KMC-' || (10000 + i),
            doc_specs[i],
            doc_exp[i],
            doc_fees[i],
            ARRAY['English', 'Hindi', 'Kannada'],
            'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=300&fit=crop&q=80',
            'Experienced ' || doc_specs[i] || ' with ' || doc_exp[i] || ' years of patient-centric clinical practice.',
            true, -- verified
            true, -- available today
            (i % 3 = 0), -- every 3rd doctor available right now
            15
        )
        ON CONFLICT (id) DO NOTHING;

        -- Link to hospital (cycle through 5 hospitals)
        INSERT INTO public.doctor_hospitals (doctor_id, hospital_id, room_number)
        VALUES (
            doc_ids[i],
            hosp_ids[((i - 1) % 5) + 1],
            'OPD Room ' || (100 + i)
        )
        ON CONFLICT (doctor_id, hospital_id) DO NOTHING;

        -- Create schedule Mon-Sat
        FOR d IN 1..6 LOOP
            INSERT INTO public.schedules (doctor_id, day_of_week, start_time, end_time, slot_duration_minutes)
            VALUES (doc_ids[i], d, '09:00:00', '17:00:00', 15)
            ON CONFLICT DO NOTHING;
        END LOOP;

        -- Initialize queue state for today
        INSERT INTO public.queue_state (doctor_id, queue_date, current_token, last_token, avg_minutes, status)
        VALUES (
            doc_ids[i],
            CURRENT_DATE,
            CASE WHEN (i % 3 = 0) THEN 8 ELSE 0 END,
            CASE WHEN (i % 3 = 0) THEN 15 ELSE 0 END,
            15,
            'active'
        )
        ON CONFLICT (doctor_id, queue_date) DO NOTHING;
    END LOOP;
END $$;

-- 3. CREATE SLOTS FOR TODAY AND TOMORROW FOR FIRST 5 DOCTORS
DO $$
DECLARE
    doc_id UUID;
    slot_d DATE;
    s_hour INT;
    s_min INT;
    start_ts TIMESTAMPTZ;
BEGIN
    FOR doc_id IN SELECT id FROM public.doctors LIMIT 5 LOOP
        FOR day_offset IN 0..1 LOOP
            slot_d := CURRENT_DATE + day_offset;
            FOR s_hour IN 9..12 LOOP
                FOR s_min IN 0..3 LOOP
                    start_ts := (slot_d || ' ' || LPAD(s_hour::text, 2, '0') || ':' || LPAD((s_min * 15)::text, 2, '0') || ':00+05:30')::TIMESTAMPTZ;
                    INSERT INTO public.slots (doctor_id, slot_date, slot_start, slot_end, status)
                    VALUES (
                        doc_id,
                        slot_d,
                        start_ts,
                        start_ts + INTERVAL '15 minutes',
                        'available'
                    )
                    ON CONFLICT (doctor_id, slot_start) DO NOTHING;
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- 4. INSERT REALISTIC COMPLETED APPOINTMENTS & REVIEWS FOR BAYESIAN RANKING
-- Creating mock patient profile
INSERT INTO public.profiles (id, email, phone, full_name, role)
VALUES 
    ('30000000-0000-0000-0000-000000000001', 'patient1@example.com', '+919900000001', 'Rohan Verma', 'patient'),
    ('30000000-0000-0000-0000-000000000002', 'patient2@example.com', '+919900000002', 'Aishwarya Sen', 'patient')
ON CONFLICT (id) DO NOTHING;

-- Seed reviews for Dr. Rajesh Sharma (Doctor 1) - Making him Top Rated (52 reviews, avg ~4.8)
DO $$
DECLARE
    r INT;
    app_id UUID;
    doc1_id UUID := '20000000-0000-0000-0000-000000000001';
    pat_id UUID := '30000000-0000-0000-0000-000000000001';
    slot_id UUID;
BEGIN
    SELECT id INTO slot_id FROM public.slots WHERE doctor_id = doc1_id LIMIT 1;
    IF slot_id IS NOT NULL THEN
        FOR r IN 1..52 LOOP
            app_id := uuid_generate_v4();
            INSERT INTO public.appointments (id, doctor_id, patient_id, slot_id, appointment_date, token_number, status)
            VALUES (app_id, doc1_id, pat_id, slot_id, CURRENT_DATE - r, r, 'completed');

            INSERT INTO public.reviews (appointment_id, doctor_id, patient_id, rating, comment, doctor_reply, doctor_replied_at)
            VALUES (
                app_id,
                doc1_id,
                pat_id,
                CASE WHEN r % 10 = 0 THEN 4 ELSE 5 END,
                'Excellent consultation and accurate diagnosis! Minimum wait time.',
                'Thank you for your feedback! Wishing you good health.',
                NOW()
            );
        END LOOP;
    END IF;
END $$;

-- Seed reviews for Dr. Sunita Kulkarni (Doctor 2) - 15 reviews, avg ~4.6
DO $$
DECLARE
    r INT;
    app_id UUID;
    doc2_id UUID := '20000000-0000-0000-0000-000000000002';
    pat2_id UUID := '30000000-0000-0000-0000-000000000002';
    slot_id UUID;
BEGIN
    SELECT id INTO slot_id FROM public.slots LIMIT 1;
    IF slot_id IS NOT NULL THEN
        FOR r IN 1..15 LOOP
            app_id := uuid_generate_v4();
            INSERT INTO public.appointments (id, doctor_id, patient_id, slot_id, appointment_date, token_number, status)
            VALUES (app_id, doc2_id, pat2_id, slot_id, CURRENT_DATE - r, r, 'completed');

            INSERT INTO public.reviews (appointment_id, doctor_id, patient_id, rating, comment)
            VALUES (
                app_id,
                doc2_id,
                pat2_id,
                CASE WHEN r % 4 = 0 THEN 4 ELSE 5 END,
                'Very polite doctor and effective skin treatment.'
            );
        END LOOP;
    END IF;
END $$;
