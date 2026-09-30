// Supabase Edge Function: create-razorpay-order
// Runtime: Deno / TypeScript (Supabase Edge Functions)
// Creates an authenticated Razorpay order and inserts a pending payment record

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface CreateOrderRequest {
  appointment_id: string;
  amount: number; // in Rupees (e.g. 500)
  currency?: string; // default INR
  mode?: "full" | "booking_fee";
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "rzp_test_placeholder";
    const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "test_secret";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body: CreateOrderRequest = await req.json();
    const { appointment_id, amount, currency = "INR", mode = "full" } = body;

    if (!appointment_id || !amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid appointment_id or amount" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Razorpay amounts are in smallest currency subunits (Paise for INR: 1 INR = 100 paise)
    const amountInPaise = Math.round(amount * 100);

    let orderId = `order_mock_${Date.now()}`;

    // If active Razorpay credentials are configured, create live test order via Razorpay Orders API
    if (razorpayKeySecret !== "test_secret" && !razorpayKeyId.includes("placeholder")) {
      const authHeader = btoa(`${razorpayKeyId}:${razorpayKeySecret}`);
      const razorpayResponse = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          Authorization: `Basic ${authHeader}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: amountInPaise,
          currency: currency,
          receipt: `rcpt_${appointment_id.substring(0, 10)}`,
          notes: {
            appointment_id: appointment_id,
            platform: "DoctorG",
          },
        }),
      });

      if (!razorpayResponse.ok) {
        const errorText = await razorpayResponse.text();
        throw new Error(`Razorpay API Error: ${errorText}`);
      }

      const rzpOrder = await razorpayResponse.json();
      orderId = rzpOrder.id;
    }

    // Insert payment record into Supabase payments table
    const { error: dbError } = await supabase.from("payments").insert({
      appointment_id: appointment_id,
      razorpay_order_id: orderId,
      amount: amount,
      currency: currency,
      status: "created",
      mode: mode,
    });

    if (dbError) {
      console.warn("Could not insert payment row in DB:", dbError.message);
    }

    return new Response(
      JSON.stringify({
        order_id: orderId,
        amount: amount,
        amount_subunits: amountInPaise,
        currency: currency,
        key_id: razorpayKeyId,
      }),
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
