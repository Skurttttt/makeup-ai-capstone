# Supabase Email Template Customization

## Custom Email Verification Template

Here's a beautiful, responsive HTML/CSS email template for FaceTune Beauty email verification:

### Template HTML/CSS Code

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
      background-color: #f8f9fa;
      line-height: 1.6;
    }
    
    .email-container {
      max-width: 600px;
      margin: 0 auto;
      background-color: #ffffff;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    }
    
    .header {
      background: linear-gradient(135deg, #FF4D97 0%, #FF1493 100%);
      padding: 40px 20px;
      text-align: center;
      color: white;
    }
    
    .header-logo {
      font-size: 28px;
      font-weight: bold;
      margin-bottom: 8px;
      letter-spacing: 0.5px;
    }
    
    .header-subtitle {
      font-size: 14px;
      opacity: 0.9;
    }
    
    .content {
      padding: 40px 30px;
    }
    
    .greeting {
      font-size: 20px;
      font-weight: 600;
      color: #333;
      margin-bottom: 20px;
    }
    
    .message {
      font-size: 14px;
      color: #555;
      margin-bottom: 30px;
      line-height: 1.8;
    }
    
    .cta-button {
      display: inline-block;
      background: linear-gradient(135deg, #FF4D97 0%, #FF1493 100%);
      color: white;
      padding: 14px 40px;
      border-radius: 6px;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
      margin-bottom: 30px;
      transition: transform 0.2s;
    }
    
    .cta-button:hover {
      transform: scale(1.02);
    }
    
    .token-section {
      background-color: #f8f9fa;
      padding: 20px;
      border-radius: 6px;
      margin-bottom: 30px;
      border-left: 4px solid #FF4D97;
    }
    
    .token-label {
      font-size: 12px;
      color: #888;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 8px;
    }
    
    .token-code {
      font-family: 'Courier New', monospace;
      font-size: 18px;
      font-weight: bold;
      color: #FF4D97;
      letter-spacing: 2px;
    }
    
    .divider {
      height: 1px;
      background-color: #eee;
      margin: 30px 0;
    }
    
    .alternative-text {
      font-size: 12px;
      color: #999;
      line-height: 1.8;
      margin-bottom: 20px;
    }
    
    .footer {
      background-color: #f8f9fa;
      padding: 30px;
      text-align: center;
      font-size: 12px;
      color: #999;
      border-top: 1px solid #eee;
    }
    
    .footer-link {
      color: #FF4D97;
      text-decoration: none;
    }
    
    .footer-divider {
      display: inline-block;
      margin: 0 8px;
      color: #ddd;
    }
    
    .security-notice {
      background-color: #fff3cd;
      border: 1px solid #ffc107;
      border-radius: 4px;
      padding: 12px;
      font-size: 12px;
      color: #856404;
      margin-bottom: 20px;
    }
    
    @media (max-width: 600px) {
      .content {
        padding: 30px 20px;
      }
      
      .greeting {
        font-size: 18px;
      }
      
      .cta-button {
        width: 100%;
        text-align: center;
        padding: 16px 20px;
      }
    }
  </style>
</head>
<body>
  <div class="email-container">
    <!-- Header -->
    <div class="header">
      <div class="header-logo">✨ FaceTune Beauty</div>
      <div class="header-subtitle">Confirm Your Email to Get Started</div>
    </div>
    
    <!-- Main Content -->
    <div class="content">
      <div class="greeting">Welcome to FaceTune Beauty!</div>
      
      <div class="message">
        Hi {{ .Email }},<br><br>
        Thank you for signing up! We're excited to have you on board. To complete your registration and unlock all the amazing features of FaceTune Beauty, please confirm your email address.
      </div>
      
      <!-- CTA Button -->
      <a href="{{ .ConfirmationURL }}" class="cta-button" style="display: inline-block; background: linear-gradient(135deg, #FF4D97 0%, #FF1493 100%); color: white; padding: 14px 40px; border-radius: 6px; text-decoration: none; font-weight: 600; font-size: 16px; margin-bottom: 30px;">
        Confirm Email Address
      </a>
      
      <div class="message">
        Or paste this code into the app:
      </div>
      
      <!-- Token Section -->
      <div class="token-section">
        <div class="token-label">Verification Code</div>
        <div class="token-code">{{ .Token }}</div>
      </div>
      
      <!-- Security Notice -->
      <div class="security-notice">
        ⚠️ This link expires in 24 hours. If you didn't create this account, you can safely ignore this email.
      </div>
      
      <div class="message" style="font-size: 13px; color: #777;">
        This email contains a secure link that only works for you. Never share this email or the link with anyone else.
      </div>
    </div>
    
    <!-- Divider -->
    <div class="divider"></div>
    
    <!-- Footer -->
    <div class="footer">
      <div>FaceTune Beauty © 2026 | All Rights Reserved</div>
      <div style="margin-top: 10px;">
        <a href="{{ .SiteURL }}" class="footer-link">Visit Website</a>
        <span class="footer-divider">|</span>
        <a href="{{ .SiteURL }}/help" class="footer-link">Help & Support</a>
        <span class="footer-divider">|</span>
        <a href="{{ .SiteURL }}/privacy" class="footer-link">Privacy Policy</a>
      </div>
      <div style="margin-top: 15px; font-size: 11px; color: #bbb;">
        You're receiving this email because you signed up for a FaceTune Beauty account.
      </div>
    </div>
  </div>
</body>
</html>
```

## How to Apply This Template

### Step 1: Go to Supabase Dashboard
1. Log in to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Authentication** → **Email Templates**

### Step 2: Edit the Confirmation Template
1. Click on **Confirm signup** template
2. Replace the subject with: `Confirm Your Email - FaceTune Beauty`
3. In the **Email body**, replace the entire content with the HTML code above
4. Click **Save**

### Step 3: Test It
1. Try signing up with a test email
2. Check if you received the customized email

## Template Variables Available

You can use these variables in your template:

- `{{ .ConfirmationURL }}` - The confirmation link
- `{{ .Token }}` - 6-digit OTP code
- `{{ .Email }}` - User's email address
- `{{ .SiteURL }}` - Your app's URL
- `{{ .TokenHash }}` - Hashed token for custom links

## Customization Tips

### Colors
- Primary Color: `#FF4D97` (FaceTune pink)
- Secondary Color: `#FF1493` (Darker pink)
- Text: `#333` (Dark gray)
- Light Background: `#f8f9fa`

### Modify the Colors
Replace `#FF4D97` and `#FF1493` with your brand colors:

```css
background: linear-gradient(135deg, YOUR_COLOR_1 0%, YOUR_COLOR_2 100%);
```

### Change Header Text
Replace "FaceTune Beauty" with your branding:

```html
<div class="header-logo">Your App Name</div>
```

### Add Your Logo
Replace the emoji with your logo:

```html
<img src="your-logo-url" alt="Logo" style="max-width: 100px; margin-bottom: 10px;">
```

## Notes

- ✅ Mobile responsive
- ✅ Works with all email clients
- ✅ Includes security warning
- ✅ Both button + OTP code options
- ✅ Professional design
- ✅ Better engagement

Already using this? Test it now by signing up!
