// supabase/functions/create-paymongo-checkout/index.ts
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
  success_url?: string;
  cancel_url?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const toPaymongoAmount = (amount: number) => Math.round(amount * 100);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const paymongoKey = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey || !paymongoKey) {
      return new Response(JSON.stringify({ error: "Missing server configuration" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser();
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

    const successUrl = body.success_url ?? Deno.env.get("PAYMONGO_SUCCESS_URL") ?? "";
    const cancelUrl = body.cancel_url ?? Deno.env.get("PAYMONGO_CANCEL_URL") ?? "";

    if (!successUrl || !cancelUrl) {
      return new Response(JSON.stringify({ error: "Missing success or cancel URL" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let amount = 0;
    let currency = "PHP";
    let description = "FaceTune Beauty";
    let metadata: Record<string, unknown> = { kind };
    let orderId: string | null = null;

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
        return new Response(JSON.stringify({ error: "Products not found" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const productMap = new Map(products.map((p) => [p.id, p]));
      const lineItems = items.map((item) => {
        const product = productMap.get(item.product_id);
        if (!product) {
          throw new Error("Invalid product_id");
        }
        const qty = Math.max(1, item.quantity ?? 1);
        const itemTotal = Number(product.price) * qty;
        amount += itemTotal;
        currency = product.currency ?? currency;
        return {
          name: product.name,
          quantity: qty,
          amount: toPaymongoAmount(Number(product.price)),
          currency,
        };
      });

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
        return new Response(JSON.stringify({ error: "Failed to create order" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
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

      const { error: itemsError } = await supabase.from("order_items").insert(orderItems);
      if (itemsError) {
        return new Response(JSON.stringify({ error: "Failed to create order items" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      description = "Marketplace order";
      metadata = { kind, order_id: orderId };

      const checkout = await createPaymongoCheckout({
        paymongoKey,
        lineItems,
        successUrl,
        cancelUrl,
        description,
        metadata,
      });

      await supabase.from("orders").update({
        provider_checkout_session_id: checkout.id,
        provider_status: checkout.status,
      }).eq("id", orderId);

      const { data: session } = await supabase.from("payment_sessions").insert({
        user_id: userData.user.id,
        session_type: "order",
        status: "pending",
        amount,
        currency,
        payment_provider: "paymongo",
        provider_checkout_session_id: checkout.id,
        provider_checkout_url: checkout.checkout_url,
        metadata,
      }).select("id").single();

      return new Response(JSON.stringify({
        checkout_url: checkout.checkout_url,
        checkout_session_id: checkout.id,
        order_id: orderId,
        payment_session_id: session?.id ?? null,
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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

      const checkout = await createPaymongoCheckout({
        paymongoKey,
        lineItems: [
          {
            name: description,
            quantity: 1,
            amount: toPaymongoAmount(amount),
            currency,
          },
        ],
        successUrl,
        cancelUrl,
        description,
        metadata,
      });

      const { data: session } = await supabase.from("payment_sessions").insert({
        user_id: userData.user.id,
        session_type: "subscription",
        status: "pending",
        amount,
        currency,
        payment_provider: "paymongo",
        provider_checkout_session_id: checkout.id,
        provider_checkout_url: checkout.checkout_url,
        metadata,
      }).select("id").single();

      return new Response(JSON.stringify({
        checkout_url: checkout.checkout_url,
        checkout_session_id: checkout.id,
        payment_session_id: session?.id ?? null,
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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

async function createPaymongoCheckout(params: {
  paymongoKey: string;
  lineItems: Array<{ name: string; quantity: number; amount: number; currency: string }>;
  successUrl: string;
  cancelUrl: string;
  description: string;
  metadata: Record<string, unknown>;
}) {
  const { paymongoKey, lineItems, successUrl, cancelUrl, description, metadata } = params;
  const response = await fetch("https://api.paymongo.com/v2/checkout_sessions", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${btoa(`${paymongoKey}:`)}`,
      "Content-Type": "application/json",
      "accept": "application/json",
    },
    body: JSON.stringify({
      data: {
        attributes: {
          line_items: lineItems,
          payment_method_types: ["card", "gcash", "paymaya"],
          success_url: successUrl,
          cancel_url: cancelUrl,
          description,
          metadata,
          show_description: true,
          show_line_items: true,
          send_email_receipt: false,
        },
      },
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.errors?.[0]?.detail ?? "PayMongo checkout failed");
  }

  const attributes = data?.data?.attributes ?? {};
  return {
    id: data?.data?.id,
    checkout_url: attributes?.checkout_url,
    status: attributes?.status ?? "pending",
  } as { id: string; checkout_url: string; status: string };
}
