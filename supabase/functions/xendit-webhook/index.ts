// @ts-nocheck
// supabase/functions/xendit-webhook/index.ts
import { serve } from "https://deno.land/std@0.204.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-callback-token",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Missing server configuration" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Optional: verify Xendit webhook token
    const xenditWebhookToken = Deno.env.get("XENDIT_WEBHOOK_TOKEN") ?? "";
    if (xenditWebhookToken) {
      const callbackToken = req.headers.get("x-callback-token") ?? "";
      if (callbackToken !== xenditWebhookToken) {
        return new Response(JSON.stringify({ error: "Invalid callback token" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const payload = await req.json();

    // Xendit sends the invoice object directly (not wrapped in data.attributes)
    // event is indicated by the "status" field on the invoice object
    const eventType = payload?.event ?? "invoice"; // v2 uses "event" field
    const invoiceStatus = payload?.status ?? payload?.data?.status ?? "";
    const invoiceId = payload?.id ?? payload?.data?.id ?? null;
    const externalId = payload?.external_id ?? payload?.data?.external_id ?? null;

    // Log raw event
    await supabase.from("payment_events").insert({
      payment_provider: "xendit",
      event_type: eventType || invoiceStatus,
      provider_event_id: invoiceId,
      payload,
    }).then(() => {});

    // invoice.paid or status=PAID
    if (
      eventType === "invoice.paid" ||
      invoiceStatus === "PAID" ||
      invoiceStatus === "SETTLED"
    ) {
      await handleInvoicePaid({ supabase, payload, invoiceId });
    }

    // invoice.expired or status=EXPIRED
    if (eventType === "invoice.expired" || invoiceStatus === "EXPIRED") {
      await handleInvoiceExpired({ supabase, invoiceId });
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 200, // always 200 to Xendit so it doesn't retry
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function handleInvoicePaid(params: {
  supabase: ReturnType<typeof createClient>;
  payload: any;
  invoiceId: string | null;
}) {
  const { supabase, payload, invoiceId } = params;
  if (!invoiceId) return;

  const { data: session } = await supabase
    .from("payment_sessions")
    .select("id, session_type, user_id, metadata, amount, currency")
    .eq("provider_checkout_session_id", invoiceId)
    .single();

  if (!session) return;

  await supabase
    .from("payment_sessions")
    .update({ status: "paid", provider_payment_id: invoiceId })
    .eq("id", session.id);

  if (session.session_type === "order") {
    await supabase
      .from("orders")
      .update({
        status: "paid",
        provider_payment_id: invoiceId,
        provider_status: "PAID",
      })
      .eq("provider_checkout_session_id", invoiceId);
    return;
  }

  if (session.session_type === "subscription") {
    const planId = session.metadata?.plan_id as string | undefined;
    if (!planId) return;

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
      payment_method: "xendit",
      amount_paid: session.amount,
      payment_provider: "xendit",
      provider_checkout_session_id: invoiceId,
      provider_payment_id: invoiceId,
    });
  }
}

async function handleInvoiceExpired(params: {
  supabase: ReturnType<typeof createClient>;
  invoiceId: string | null;
}) {
  const { supabase, invoiceId } = params;
  if (!invoiceId) return;

  await supabase
    .from("payment_sessions")
    .update({ status: "failed" })
    .eq("provider_checkout_session_id", invoiceId);

  await supabase
    .from("orders")
    .update({ status: "cancelled", provider_status: "EXPIRED" })
    .eq("provider_checkout_session_id", invoiceId);
}

function addPeriod(start: Date, billingPeriod: string): Date {
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
