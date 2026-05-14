# Supabase Email Template Customization

## Email Confirmation Template (v2 — Email-Client Safe)

> **Why the rewrite?** The previous version used a `<style>` block and CSS class names.
> Gmail, Apple Mail, and many others **strip the `<style>` block entirely**, leaving
> unstyled text. This version uses:
> - **Fully inline styles** on every element — nothing can be stripped
> - **Table-based layout** — the only layout that renders correctly in Outlook
> - **Preheader text** — the preview line users see before opening the email
> - **Individual OTP digit boxes** — visually clear, like Stripe / Apple
> - **Outlook VML button fallback** — the button shows properly in Outlook desktop

---

### Template HTML (Copy this entire block into Supabase)

```html
<!DOCTYPE html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="x-apple-disable-message-reformatting">
  <title>Confirm Your Email – FaceTune Beauty</title>
  <!--[if mso]>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <![endif]-->
</head>
<body style="margin:0;padding:0;background-color:#f4f4f8;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;">

  <!-- Preheader: shows as preview text in inbox, hidden in email body -->
  <div style="display:none;font-size:1px;color:#f4f4f8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
    Confirm your FaceTune Beauty account — your verification code is inside ✨
  </div>

  <!-- Outer wrapper -->
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f4f4f8;">
    <tr>
      <td align="center" style="padding:40px 16px;">

        <!-- Email card -->
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e8e8ee;">

          <!-- ===== HEADER ===== -->
          <tr>
            <td align="center" style="background-color:#FF1493;padding:44px 30px 36px;">
              <!--[if mso]>
              <table cellpadding="0" cellspacing="0" border="0" width="100%"><tr><td align="center">
              <![endif]-->
              <!-- Sparkle icon row -->
              <table cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" style="background-color:rgba(255,255,255,0.18);border-radius:50%;width:64px;height:64px;font-size:30px;line-height:64px;text-align:center;">
                    ✨
                  </td>
                </tr>
              </table>
              <div style="height:14px;"></div>
              <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:26px;font-weight:700;color:#ffffff;letter-spacing:0.4px;">
                FaceTune Beauty
              </p>
              <div style="height:6px;"></div>
              <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:14px;color:rgba(255,255,255,0.88);letter-spacing:0.2px;">
                Confirm your email to get started
              </p>
              <!--[if mso]>
              </td></tr></table>
              <![endif]-->
            </td>
          </tr>

          <!-- ===== MAIN CONTENT ===== -->
          <tr>
            <td style="padding:40px 40px 32px;">

              <!-- Greeting -->
              <p style="margin:0 0 8px;font-family:Arial,Helvetica,sans-serif;font-size:22px;font-weight:700;color:#1a1a2e;">
                Welcome aboard! 🎉
              </p>
              <p style="margin:0 0 24px;font-family:Arial,Helvetica,sans-serif;font-size:15px;color:#555566;line-height:1.7;">
                Hi <strong style="color:#1a1a2e;">{{ .Email }}</strong>,<br><br>
                Thanks for joining FaceTune Beauty! You're one step away from unlocking your personalized AI beauty experience. Please confirm your email address below.
              </p>

              <!-- ===== CTA BUTTON (Outlook-safe VML + HTML fallback) ===== -->
              <table cellpadding="0" cellspacing="0" border="0" style="margin-bottom:32px;">
                <tr>
                  <td align="center">
                    <!--[if mso]>
                    <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word"
                      href="{{ .ConfirmationURL }}"
                      style="height:52px;v-text-anchor:middle;width:260px;"
                      arcsize="12%"
                      strokecolor="#FF1493"
                      fillcolor="#FF1493">
                      <w:anchorlock/>
                      <center style="color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:17px;font-weight:bold;">
                        Confirm Email Address
                      </center>
                    </v:roundrect>
                    <![endif]-->
                    <!--[if !mso]><!-->
                    <a href="{{ .ConfirmationURL }}"
                       style="display:inline-block;background-color:#FF1493;color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:17px;font-weight:700;text-decoration:none;padding:15px 40px;border-radius:8px;letter-spacing:0.3px;mso-hide:all;">
                      Confirm Email Address
                    </a>
                    <!--<![endif]-->
                  </td>
                </tr>
              </table>

              <!-- Divider with OR -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:28px;">
                <tr>
                  <td style="border-bottom:1px solid #e8e8ee;width:44%;"></td>
                  <td align="center" style="width:12%;padding:0 12px;white-space:nowrap;">
                    <span style="font-family:Arial,Helvetica,sans-serif;font-size:12px;color:#aaaabc;text-transform:uppercase;letter-spacing:1px;">or</span>
                  </td>
                  <td style="border-bottom:1px solid #e8e8ee;width:44%;"></td>
                </tr>
              </table>

              <!-- OTP Section label -->
              <p style="margin:0 0 16px;font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#555566;text-align:center;">
                Enter this code in the app to verify your account:
              </p>

              <!-- ===== OTP CODE BOX ===== -->
              <table cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto 28px;">
                <tr>
                  <td align="center" style="background-color:#fff0f6;border:2px solid #FF1493;border-radius:10px;padding:20px 36px;">
                    <!-- Small label -->
                    <p style="margin:0 0 10px;font-family:Arial,Helvetica,sans-serif;font-size:11px;font-weight:700;color:#FF1493;text-transform:uppercase;letter-spacing:2px;">
                      Verification Code
                    </p>
                    <!-- The code itself -->
                    <p style="margin:0;font-family:'Courier New',Courier,monospace;font-size:36px;font-weight:700;color:#1a1a2e;letter-spacing:10px;line-height:1;">
                      {{ .Token }}
                    </p>
                    <!-- Expiry note inside box -->
                    <p style="margin:10px 0 0;font-family:Arial,Helvetica,sans-serif;font-size:11px;color:#aaaabc;">
                      Expires in 24 hours
                    </p>
                  </td>
                </tr>
              </table>

              <!-- Security notice -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:24px;">
                <tr>
                  <td style="background-color:#fff8e6;border:1px solid #ffd966;border-radius:6px;padding:13px 16px;">
                    <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:12px;color:#7a5c00;line-height:1.6;">
                      <strong>⚠ Security reminder:</strong> FaceTune Beauty will never ask for this code by phone or chat. If you didn't sign up, you can safely ignore this email — no account will be created.
                    </p>
                  </td>
                </tr>
              </table>

              <!-- Fine print -->
              <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:12px;color:#aaaabc;line-height:1.7;">
                Button not working? Copy and paste this link into your browser:<br>
                <a href="{{ .ConfirmationURL }}" style="color:#FF1493;word-break:break-all;text-decoration:underline;">{{ .ConfirmationURL }}</a>
              </p>

            </td>
          </tr>

          <!-- ===== DIVIDER ===== -->
          <tr>
            <td style="padding:0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr><td style="border-top:1px solid #e8e8ee;font-size:0;line-height:0;">&nbsp;</td></tr>
              </table>
            </td>
          </tr>

          <!-- ===== FOOTER ===== -->
          <tr>
            <td style="background-color:#fafafa;padding:28px 40px;border-radius:0 0 12px 12px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center">
                    <p style="margin:0 0 10px;font-family:Arial,Helvetica,sans-serif;font-size:12px;color:#aaaabc;">
                      FaceTune Beauty &copy; 2026 &nbsp;|&nbsp; All Rights Reserved
                    </p>
                    <p style="margin:0 0 10px;font-family:Arial,Helvetica,sans-serif;font-size:12px;">
                      <a href="{{ .SiteURL }}" style="color:#FF1493;text-decoration:none;">Website</a>
                      &nbsp;&nbsp;·&nbsp;&nbsp;
                      <a href="{{ .SiteURL }}/help" style="color:#FF1493;text-decoration:none;">Help &amp; Support</a>
                      &nbsp;&nbsp;·&nbsp;&nbsp;
                      <a href="{{ .SiteURL }}/privacy" style="color:#FF1493;text-decoration:none;">Privacy Policy</a>
                    </p>
                    <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:11px;color:#c8c8d4;">
                      You received this email because you created a FaceTune Beauty account.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>
        <!-- /Email card -->

      </td>
    </tr>
  </table>
  <!-- /Outer wrapper -->

</body>
</html>
```

---

## How to Apply This Template

### Step 1: Go to Supabase Dashboard
1. Log in to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Authentication** → **Email Templates**

### Step 2: Edit the Confirmation Template
1. Click on **Confirm signup** template
2. Set the **Subject** to:
   ```
   Confirm your FaceTune Beauty account ✨
   ```
3. Replace the entire **Email body** with the HTML block above
4. Click **Save**

### Step 3: Test
1. Sign up with a test email address
2. Check that the email renders correctly
3. Verify the button link and OTP code both work

---

## Template Variables Reference

| Variable | Description |
|---|---|
| `{{ .ConfirmationURL }}` | One-click confirmation link |
| `{{ .Token }}` | 6-digit OTP code |
| `{{ .Email }}` | User's email address |
| `{{ .SiteURL }}` | Your app's base URL |
| `{{ .TokenHash }}` | Hashed token for custom deep-link flows |

---

## What Changed vs. v1

| Issue in v1 | Fix in v2 |
|---|---|
| `<style>` block stripped by Gmail | All styles are **inline** on every element |
| `<div>` layout broken in Outlook | **Table-based layout** throughout |
| CSS `transition` / `transform` ignored | Removed — not supported in email |
| No inbox preview text | **Preheader** hidden span added |
| OTP code hard to read | Large monospace code in a **pink bordered box** |
| Button invisible in Outlook | **VML `<v:roundrect>` fallback** added |
| Fallback link missing | Raw URL shown below button |

---

## Brand Color Reference

| Token | Hex | Use |
|---|---|---|
| Primary | `#FF1493` | Header, button, accents |
| OTP box border | `#FF1493` | OTP section border |
| OTP box fill | `#fff0f6` | OTP section background |
| Body text | `#1a1a2e` | Headings |
| Muted text | `#555566` | Body copy |
| Background | `#f4f4f8` | Email outer background |

To change the brand color, replace every instance of `#FF1493` with your new hex value.
