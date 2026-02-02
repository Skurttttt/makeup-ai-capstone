// SUPABASE SETUP GUIDE

## Step 1: Create Supabase Account
1. Go to https://supabase.com
2. Sign up with email or GitHub
3. Create a new project:
   - Name: "FaceTuneBeauty"
   - Region: Choose closest to you
   - Password: Generate strong password
4. Wait for project to provision (~2 min)

## Step 2: Get Your Credentials
In Supabase dashboard:
1. Go to Settings → API
2. Copy these values:
   - Supabase URL (e.g., https://xxxxx.supabase.co)
   - Anon Public Key (safe to share with client)
   - Service Role Key (KEEP SECRET - never share)

## Step 3: Add to Your Project
Save in assets/.env file:
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_KEY=your_service_key_here
```

## Step 4: Update pubspec.yaml
Add dependencies:
```yaml
dependencies:
  supabase_flutter: ^1.10.0
  supabase: ^1.10.0
  http: ^1.1.0
```

Then run: flutter pub get
