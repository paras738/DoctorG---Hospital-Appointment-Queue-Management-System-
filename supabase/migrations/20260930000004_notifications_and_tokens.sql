-- DoctorG: Push Notifications & Device Tokens Schema
-- Migration 04: FCM Device Tokens, In-App Notifications & RLS Policies

-- 1. DEVICE TOKENS (FCM v1 Device Token Storage)
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT unique_user_fcm_token UNIQUE (user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens (user_id);

-- 2. IN-APP NOTIFICATIONS LOG
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'queue_alert' CHECK (type IN ('queue_alert', 'reminder', 'delay', 'cancellation', 'availability')),
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_date ON public.notifications (user_id, created_at DESC);

-- 3. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can manage their own device tokens
CREATE POLICY "Users manage own device tokens"
ON public.device_tokens FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Users see their own notifications
CREATE POLICY "Users view own notifications"
ON public.notifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Users can update (mark as read) their own notifications
CREATE POLICY "Users update own notifications"
ON public.notifications FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Notifications inserted via Service Role Key (Edge Functions) bypass RLS
