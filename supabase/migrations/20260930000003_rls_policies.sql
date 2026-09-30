-- DoctorG: Row Level Security (RLS) Policies
-- Migration 03: Enabling RLS on every table and defining strict role-based access

-- Helper function to check if caller is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper function to check if caller is a doctor
CREATE OR REPLACE FUNCTION public.is_doctor()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'doctor'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 1. PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by authenticated users"
ON public.profiles FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id);

-- 2. FAMILY MEMBERS
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view and manage their own family members"
ON public.family_members FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 3. HOSPITALS
ALTER TABLE public.hospitals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Hospitals are viewable by everyone"
ON public.hospitals FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Only admins can modify hospitals"
ON public.hospitals FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 4. DOCTORS
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Verified doctors are viewable by all; unverified by self and admin"
ON public.doctors FOR SELECT
TO authenticated, anon
USING (is_verified = true OR auth.uid() = id OR public.is_admin());

CREATE POLICY "Doctors can update their own profile; admins can update all"
ON public.doctors FOR UPDATE
TO authenticated
USING (auth.uid() = id OR public.is_admin())
WITH CHECK (auth.uid() = id OR public.is_admin());

CREATE POLICY "Doctors can insert their own doctor record"
ON public.doctors FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 5. DOCTOR_HOSPITALS
ALTER TABLE public.doctor_hospitals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctor-hospital affiliations are viewable by all"
ON public.doctor_hospitals FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Doctors or admins can manage affiliations"
ON public.doctor_hospitals FOR ALL
TO authenticated
USING (auth.uid() = doctor_id OR public.is_admin())
WITH CHECK (auth.uid() = doctor_id OR public.is_admin());

-- 6. SCHEDULES
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Schedules are viewable by all"
ON public.schedules FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Doctors can manage their own schedule"
ON public.schedules FOR ALL
TO authenticated
USING (auth.uid() = doctor_id OR public.is_admin())
WITH CHECK (auth.uid() = doctor_id OR public.is_admin());

-- 7. SLOTS
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Available and booked slots are viewable by all"
ON public.slots FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Doctors can manage their own slots"
ON public.slots FOR ALL
TO authenticated
USING (auth.uid() = doctor_id OR public.is_admin())
WITH CHECK (auth.uid() = doctor_id OR public.is_admin());

-- 8. APPOINTMENTS
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients see only their appointments; doctors see their clinic appointments"
ON public.appointments FOR SELECT
TO authenticated
USING (auth.uid() = patient_id OR auth.uid() = doctor_id OR public.is_admin());

CREATE POLICY "Patients can create appointments for themselves"
ON public.appointments FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients and doctors can update relevant appointment status"
ON public.appointments FOR UPDATE
TO authenticated
USING (auth.uid() = patient_id OR auth.uid() = doctor_id OR public.is_admin())
WITH CHECK (auth.uid() = patient_id OR auth.uid() = doctor_id OR public.is_admin());

-- 9. QUEUE STATE (Realtime)
ALTER TABLE public.queue_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Queue state is viewable by all authenticated users"
ON public.queue_state FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Only the specific doctor or admin can update queue state"
ON public.queue_state FOR ALL
TO authenticated
USING (auth.uid() = doctor_id OR public.is_admin())
WITH CHECK (auth.uid() = doctor_id OR public.is_admin());

-- 10. QUEUE TOKENS
ALTER TABLE public.queue_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients see own token; doctors see clinic tokens"
ON public.queue_tokens FOR SELECT
TO authenticated
USING (
    doctor_id = auth.uid() 
    OR appointment_id IN (SELECT id FROM public.appointments WHERE patient_id = auth.uid())
    OR public.is_admin()
);

CREATE POLICY "Doctors can update token status"
ON public.queue_tokens FOR UPDATE
TO authenticated
USING (doctor_id = auth.uid() OR public.is_admin())
WITH CHECK (doctor_id = auth.uid() OR public.is_admin());

-- 11. PAYMENTS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients see their own payments; doctors see payments for their appointments"
ON public.payments FOR SELECT
TO authenticated
USING (
    appointment_id IN (SELECT id FROM public.appointments WHERE patient_id = auth.uid() OR doctor_id = auth.uid())
    OR public.is_admin()
);

-- Payments are inserted/updated primarily via Supabase Edge Function (Service Role Key), bypassing RLS

-- 12. REVIEWS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reviews are viewable by all"
ON public.reviews FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Verified patient can create review for their completed appointment"
ON public.reviews FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = patient_id
    AND EXISTS (
        SELECT 1 FROM public.appointments
        WHERE id = appointment_id 
          AND patient_id = auth.uid() 
          AND status = 'completed'
    )
);

CREATE POLICY "Doctors can reply to reviews on their profile"
ON public.reviews FOR UPDATE
TO authenticated
USING (auth.uid() = doctor_id OR auth.uid() = patient_id OR public.is_admin())
WITH CHECK (auth.uid() = doctor_id OR auth.uid() = patient_id OR public.is_admin());

-- 13. REVIEW REPORTS
ALTER TABLE public.review_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can create review reports"
ON public.review_reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Admins can view and manage review reports"
ON public.review_reports FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 14. FOLLOWS
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their doctor follows"
ON public.follows FOR ALL
TO authenticated
USING (auth.uid() = patient_id)
WITH CHECK (auth.uid() = patient_id);

-- 15. NOTIFICATION TOKENS
ALTER TABLE public.notification_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can register and delete their FCM tokens"
ON public.notification_tokens FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 16. NOTIFICATION PREFS
ALTER TABLE public.notification_prefs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view and update their notification preferences"
ON public.notification_prefs FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
