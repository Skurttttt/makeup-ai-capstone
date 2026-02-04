// @ts-nocheck
// supabase/functions/send-verification-email/index.ts
import { serve } from "https://deno.land/std@0.204.0/http/server.ts";

serve(async (req) => {
  try {
    const { email, confirmUrl } = await req.json();

    if (!email) {
      return new Response(JSON.stringify({ error: "Missing email" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const fromEmail = Deno.env.get("RESEND_FROM") ?? "FaceTune Beauty <noreply@your-domain.com>";

    if (!resendKey) {
      return new Response(JSON.stringify({ error: "Missing RESEND_API_KEY" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const confirmLink = confirmUrl ?? "https://your-domain.com/confirm";

    const resp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: email,
        subject: "Confirm your FaceTune Beauty account",
        html: `
          <div style="font-family:Arial,sans-serif;background:#f6f7fb;padding:24px;">
            <div style="max-width:620px;margin:0 auto;background:#ffffff;border-radius:16px;padding:32px;box-shadow:0 8px 30px rgba(0,0,0,0.08);">
              <div style="text-align:center;">
                <div style="display:inline-block;background:#ffe6f0;color:#ff4d97;padding:8px 14px;border-radius:999px;font-size:12px;font-weight:600;letter-spacing:0.4px;">
                  FACETUNE BEAUTY
                </div>
                <h1 style="margin:16px 0 8px 0;font-size:26px;color:#1f2937;">Confirm your account</h1>
                <p style="margin:0 0 24px 0;color:#6b7280;font-size:15px;">
                  Tap the button below to confirm your FaceTune Beauty account and start exploring your personalized looks.
                </p>
                <a href="${confirmLink}" style="display:inline-block;background:#ff4d97;color:#ffffff;text-decoration:none;font-weight:600;padding:14px 28px;border-radius:10px;box-shadow:0 8px 20px rgba(255,77,151,0.3);">
                  Confirm my account
                </a>
                <p style="margin:24px 0 0 0;color:#9ca3af;font-size:12px;">
                  If you didn’t create this account, you can safely ignore this email.
                </p>
              </div>
              <div style="margin-top:28px;border-top:1px solid #f0f1f5;padding-top:16px;color:#9ca3af;font-size:12px;text-align:center;">
                Need help? Reply to this email or visit our support page.
              </div>
            </div>
          </div>
        `,
      }),
    });

    const data = await resp.json();
    return new Response(JSON.stringify(data), {
      status: resp.ok ? 200 : 500,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
