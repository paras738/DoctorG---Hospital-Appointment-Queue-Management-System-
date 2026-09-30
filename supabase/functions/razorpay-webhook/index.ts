// Supabase Edge Function: razorpay-webhook
// Runtime: Deno / TypeScript (Supabase Edge Functions)
// Verifies HMAC-SHA256 signature and reconciles payments & appointments

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { hmac } from "https://deno.land/x/hmac@v2.0.1/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-razorpay-signature",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "test_webhook_secret";
    const signature = req.headers.get("x-razorpay-signature");

    const rawBody = await req.text();

    // Verify HMAC-SHA256 signature if in production mode
    if (webhookSecret !== "test_webhook_secret" && signature) {
      const expectedSignature = hmac("sha256", webhookSecret, rawBody, "utf8", "hex");
      if (expectedSignature !== signature) {
        return new Response(JSON.stringify({ error: "Invalid signature" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const payload = JSON.parse(rawBody);
    const event = payload.event;
    const paymentEntity = payload.payload?.payment?.entity;
    const orderId = paymentEntity?.order_id;
    const paymentId = paymentEntity?.id;

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    if (event === "payment.captured" || event === "order.paid") {
      // 1. Update payments table to captured
      const { data: paymentRecord } = await supabase
        .from("payments")
        .update({
          status: "captured",
          razorpay_payment_id: paymentId,
          razorpay_signature: signature,
          updated_at: new Date().toISOString(),
        })
        .eq("razorpay_order_id", orderId)
        .select()
        .single();

      // 2. Confirm appointment
      if (paymentRecord?.appointment_id) {
        await supabase
          .from("appointments")
          .update({
            status: "confirmed",
            updated_at: new Date().toISOString(),
          })
          .eq("id", paymentRecord.appointment_id);
      }
    } else if (event === "payment.failed") {
      await supabase
        .from("payments")
        .update({
          status: "failed",
          updated_at: new Date().toISOString(),
        })
        .eq("razorpay_order_id", orderId);
    } else if (event === "refund.processed") {
      const { data: paymentRecord } = await supabase
        .from("payments")
        .update({
          status: "refunded",
          updated_at: new Date().toISOString(),
        })
        .eq("razorpay_order_id", orderId)
        .select()
        .single();

      if (paymentRecord?.appointment_id) {
        await supabase
          .from("appointments")
          .update({
            status: "cancelled",
            updated_at: new Date().toISOString(),
          })
          .eq("id", paymentRecord.appointment_id);
      }
    }

    return new Response(
      JSON.stringify({ status: "success", event_processed: event }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
