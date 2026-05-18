// @ts-nocheck
// supabase/functions/create-xendit-checkout/index.ts
import { serve } from "https://deno.land/std@0.204.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type CheckoutItem = {
  product_id: string;
  quantity: number;
};

type CheckoutRequest = {
  kind: "order" | "subscription";
  items?: CheckoutItem[];
  plan_id?: string;
  payment_method?: string;
  success_url?: string;
  cancel_url?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Xendit payment methods mapping
const resolveXenditPaymentMethods = (paymentMethod?: string): string[] => {
  switch ((paymentMethod ?? "").toLowerCase()) {
    case "xendit":
    case "card":
    case "credit_card":
      return ["CREDIT_CARD"];
    case "gcash":
      return ["GCASH"];
    case "paymaya":
    case "maya":
      return ["PAYMAYA"];
    case "otc":
      return ["OTC"];
    default:
      // Allow all common PH payment methods
      return ["CREDIT_CARD", "GCASH", "PAYMAYA", "OTC"];
  }
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    let xenditKey = Deno.env.get("XENDIT_SECRET_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Missing server configuration" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const dbClient = createClient(supabaseUrl, supabaseServiceKey);

    // Fallback: read Xendit key from app_config table if not in env
    if (!xenditKey) {
      try {
        const { data: cfg } = await dbClient
          .from("app_config")
          .select("value")
          .eq("key", "XENDIT_SECRET_KEY")
          .maybeSingle();
        if (cfg?.value) xenditKey = cfg.value;
      } catch (_) { /* ignore */ }
    }

    if (!xenditKey) {
      return new Response(
        JSON.stringify({ error: "Missing XENDIT_SECRET_KEY" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } =
      await supabase.auth.getUser();
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json()) as CheckoutRequest;
    const kind = body.kind;
    if (!kind) {
      return new Response(JSON.stringify({ error: "Missing kind" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Resolve redirect URLs (env → DB fallback)
    let successUrl = body.success_url ?? Deno.env.get("XENDIT_SUCCESS_URL") ?? "";
    let cancelUrl = body.cancel_url ?? Deno.env.get("XENDIT_CANCEL_URL") ?? "";

    if (!successUrl || !cancelUrl) {
      try {
        if (!successUrl) {
          const { data: s } = await dbClient
            .from("app_config")
            .select("value")
            .eq("key", "XENDIT_SUCCESS_URL")
            .maybeSingle();
          if (s?.value) successUrl = s.value;
        }
        if (!cancelUrl) {
          const { data: c } = await dbClient
            .from("app_config")
            .select("value")
            .eq("key", "XENDIT_CANCEL_URL")
            .maybeSingle();
          if (c?.value) cancelUrl = c.value;
        }
      } catch (_) { /* ignore */ }
    }

    if (!successUrl || !cancelUrl) {
      return new Response(
        JSON.stringify({ error: "Missing success or cancel URL" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    let amount = 0;
    let currency = "PHP";
    let description = "FaceTune Beauty";
    let metadata: Record<string, unknown> = { kind };
    let orderId: string | null = null;
    let xenditItems: Array<{
      name: string;
      quantity: number;
      price: number;
      category: string;
    }> = [];

    // ── ORDER ────────────────────────────────────────────────────────────────
    if (kind === "order") {
      const items = body.items ?? [];
      if (items.length === 0) {
        return new Response(JSON.stringify({ error: "Missing items" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const productIds = [...new Set(items.map((i) => i.product_id))];
      const { data: products, error: productsError } = await supabase
        .from("products")
        .select("id, name, price, currency, business_id")
        .in("id", productIds);

      if (productsError || !products || products.length === 0) {
        return new Response(
          JSON.stringify({ error: "Products not found" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const productMap = new Map(products.map((p) => [p.id, p]));

      for (const item of items) {
        const product = productMap.get(item.product_id);
        if (!product) throw new Error("Invalid product_id");
        const qty = Math.max(1, item.quantity ?? 1);
        const unitPrice = Number(product.price);
        amount += unitPrice * qty;
        currency = product.currency ?? currency;
        xenditItems.push({
          name: product.name,
          quantity: qty,
          price: unitPrice,
          category: "Marketplace",
        });
      }

      // Create order record
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .insert({
          buyer_id: userData.user.id,
          subtotal: amount,
          total: amount,
          currency,
          status: "pending",
        })
        .select("id")
        .single();

      if (orderError || !order) {
        return new Response(
          JSON.stringify({ error: "Failed to create order" }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      orderId = order.id;

      const orderItems = items.map((item) => {
        const product = productMap.get(item.product_id)!;
        const qty = Math.max(1, item.quantity ?? 1);
        const unitPrice = Number(product.price);
        return {
          order_id: orderId,
          product_id: product.id,
          business_id: product.business_id,
          quantity: qty,
          unit_price: unitPrice,
          total_price: unitPrice * qty,
        };
      });

      await supabase.from("order_items").insert(orderItems);

      description = "Marketplace order";
      metadata = { kind, order_id: orderId };

      const invoice = await createXenditInvoice({
        xenditKey,
        externalId: `order-${orderId}`,
        amount,
        currency,
        description,
        successRedirectUrl: successUrl,
        failureRedirectUrl: cancelUrl,
        customerEmail: userData.user.email,
        items: xenditItems,
        paymentMethods: resolveXenditPaymentMethods(body.payment_method),
        metadata,
      });

      await supabase
        .from("orders")
        .update({
          provider_checkout_session_id: invoice.id,
          provider_status: invoice.status,
        })
        .eq("id", orderId);

      const { data: session } = await supabase
        .from("payment_sessions")
        .insert({
          user_id: userData.user.id,
          session_type: "order",
          status: "pending",
          amount,
          currency,
          payment_provider: "xendit",
          provider_checkout_session_id: invoice.id,
          provider_checkout_url: invoice.invoice_url,
          metadata,
        })
        .select("id")
        .single();

      return new Response(
        JSON.stringify({
          checkout_url: invoice.invoice_url,
          checkout_session_id: invoice.id,
          order_id: orderId,
          payment_session_id: session?.id ?? null,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // ── SUBSCRIPTION ─────────────────────────────────────────────────────────
    if (kind === "subscription") {
      const planId = body.plan_id;
      if (!planId) {
        return new Response(JSON.stringify({ error: "Missing plan_id" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: plan, error: planError } = await supabase
        .from("subscription_plans")
        .select("id, display_name, price, currency, billing_period")
        .eq("id", planId)
        .single();

      if (planError || !plan) {
        return new Response(JSON.stringify({ error: "Plan not found" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      amount = Number(plan.price ?? 0);
      currency = plan.currency ?? "PHP";
      description = plan.display_name ?? "Subscription";
      metadata = {
        kind,
        plan_id: plan.id,
        billing_period: plan.billing_period,
      };

      xenditItems = [
        {
          name: description,
          quantity: 1,
          price: amount,
          category: "Subscription",
        },
      ];

      const invoice = await createXenditInvoice({
        xenditKey,
        externalId: `sub-${plan.id}-${userData.user.id}-${Date.now()}`,
        amount,
        currency,
        description,
        successRedirectUrl: successUrl,
        failureRedirectUrl: cancelUrl,
        customerEmail: userData.user.email,
        items: xenditItems,
        paymentMethods: resolveXenditPaymentMethods(body.payment_method),
        metadata,
      });

      const { data: session } = await supabase
        .from("payment_sessions")
        .insert({
          user_id: userData.user.id,
          session_type: "subscription",
          status: "pending",
          amount,
          currency,
          payment_provider: "xendit",
          provider_checkout_session_id: invoice.id,
          provider_checkout_url: invoice.invoice_url,
          metadata,
        })
        .select("id")
        .single();

      return new Response(
        JSON.stringify({
          checkout_url: invoice.invoice_url,
          checkout_session_id: invoice.id,
          payment_session_id: session?.id ?? null,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify({ error: "Unsupported kind" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ── Xendit Invoice creation helper ───────────────────────────────────────────
async function createXenditInvoice(params: {
  xenditKey: string;
  externalId: string;
  amount: number;
  currency: string;
  description: string;
  successRedirectUrl: string;
  failureRedirectUrl: string;
  customerEmail?: string;
  items: Array<{ name: string; quantity: number; price: number; category: string }>;
  paymentMethods: string[];
  metadata: Record<string, unknown>;
}) {
  const {
    xenditKey,
    externalId,
    amount,
    currency,
    description,
    successRedirectUrl,
    failureRedirectUrl,
    customerEmail,
    items,
    paymentMethods,
    metadata,
  } = params;

  const body: Record<string, unknown> = {
    external_id: externalId,
    amount,
    currency,
    description,
    success_redirect_url: successRedirectUrl,
    failure_redirect_url: failureRedirectUrl,
    payment_methods: paymentMethods,
    items,
    metadata,
  };

  if (customerEmail) {
    body.customer = { email: customerEmail };
    body.customer_notification_preference = {
      invoice_created: ["email"],
      invoice_reminder: ["email"],
      invoice_paid: ["email"],
    };
  }

  const response = await fetch("https://api.xendit.co/v2/invoices", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${xenditKey}:`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Xendit API error (${response.status}): ${errText}`);
  }

  return await response.json();
}
