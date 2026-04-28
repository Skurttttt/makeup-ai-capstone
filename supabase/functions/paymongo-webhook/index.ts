// supabase/functions/paymongo-webhook/index.ts
import { serve } from "https://deno.land/std@0.204.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: "Missing server configuration" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const payload = await req.json();
    const eventType =
      payload?.data?.attributes?.type ??
      payload?.data?.type ??
      payload?.type ??
      "unknown";

    const providerEventId = payload?.data?.id ?? null;

    await supabase.from("payment_events").insert({
      payment_provider: "paymongo",
      event_type: eventType,
      provider_event_id: providerEventId,
      payload,
    });

    if (eventType === "checkout_session.payment.paid") {
      await handleCheckoutPaid({ supabase, payload });
    }

    if (eventType === "payment.failed") {
      await handlePaymentFailed({ supabase, payload });
    }

    if (eventType?.startsWith("subscription.")) {
      await handleSubscriptionEvent({ supabase, payload, eventType });
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function handleCheckoutPaid(params: {
  supabase: ReturnType<typeof createClient>;
  payload: any;
}) {
  const { supabase, payload } = params;
  const checkoutData = payload?.data?.attributes?.data ?? payload?.data ?? payload;
  const checkoutId = checkoutData?.id ?? checkoutData?.attributes?.checkout_session_id;
  const paymentId = checkoutData?.attributes?.payment_id ?? null;

  if (!checkoutId) {
    return;
  }

  const { data: session } = await supabase
    .from("payment_sessions")
    .select("id, session_type, user_id, metadata, amount, currency")
    .eq("provider_checkout_session_id", checkoutId)
    .single();

  if (!session) {
    return;
  }

  await supabase.from("payment_sessions").update({
    status: "paid",
    provider_payment_id: paymentId,
  }).eq("id", session.id);

  if (session.session_type === "order") {
    await supabase.from("orders").update({
      status: "paid",
      provider_payment_id: paymentId,
      provider_status: "paid",
    }).eq("provider_checkout_session_id", checkoutId);
    return;
  }

  if (session.session_type === "subscription") {
    const planId = session.metadata?.plan_id as string | undefined;
    if (!planId) {
      return;
    }

    const { data: plan } = await supabase
      .from("subscription_plans")
      .select("id, billing_period")
      .eq("id", planId)
      .single();

    const periodEnd = addPeriod(new Date(), plan?.billing_period ?? "month");

    await supabase.from("user_subscriptions").insert({
      user_id: session.user_id,
      plan_id: planId,
      status: "active",
      started_at: new Date().toISOString(),
      current_period_start: new Date().toISOString(),
      current_period_end: periodEnd.toISOString(),
      payment_method: "paymongo",
      amount_paid: session.amount,
      payment_provider: "paymongo",
      provider_checkout_session_id: checkoutId,
      provider_payment_id: paymentId,
    });
  }
}

async function handlePaymentFailed(params: {
  supabase: ReturnType<typeof createClient>;
  payload: any;
}) {
  const { supabase, payload } = params;
  const paymentData = payload?.data?.attributes?.data ?? payload?.data ?? payload;
  const paymentId = paymentData?.id ?? null;

  if (!paymentId) {
    return;
  }

  await supabase.from("payment_sessions").update({
    status: "failed",
    provider_payment_id: paymentId,
  }).eq("provider_payment_id", paymentId);
}

async function handleSubscriptionEvent(params: {
  supabase: ReturnType<typeof createClient>;
  payload: any;
  eventType: string;
}) {
  const { supabase, payload, eventType } = params;
  const subData = payload?.data?.attributes?.data ?? payload?.data ?? payload;
  const subscriptionId = subData?.id ?? null;

  if (!subscriptionId) {
    return;
  }

  if (eventType === "subscription.past_due") {
    await supabase.from("user_subscriptions").update({
      status: "past_due",
      provider_subscription_id: subscriptionId,
    }).eq("provider_subscription_id", subscriptionId);
  }

  if (eventType === "subscription.unpaid") {
    await supabase.from("user_subscriptions").update({
      status: "expired",
      provider_subscription_id: subscriptionId,
    }).eq("provider_subscription_id", subscriptionId);
  }

  if (eventType === "subscription.updated") {
    await supabase.from("user_subscriptions").update({
      provider_subscription_id: subscriptionId,
    }).eq("provider_subscription_id", subscriptionId);
  }
}

function addPeriod(start: Date, billingPeriod: string) {
  const end = new Date(start.getTime());
  switch (billingPeriod) {
    case "week":
      end.setDate(end.getDate() + 7);
      break;
    case "3months":
      end.setMonth(end.getMonth() + 3);
      break;
    case "6months":
      end.setMonth(end.getMonth() + 6);
      break;
    case "year":
      end.setFullYear(end.getFullYear() + 1);
      break;
    case "lifetime":
      end.setFullYear(end.getFullYear() + 100);
      break;
    default:
      end.setMonth(end.getMonth() + 1);
  }
  return end;
}
