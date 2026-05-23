Create test users for local/dev Supabase

1) Install dependencies

```bash
npm init -y
npm install @supabase/supabase-js
```

2) Set environment variables (replace with your project values)

On macOS / Linux:
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

On Windows PowerShell:
```powershell
$env:SUPABASE_URL = 'https://your-project.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY = 'your-service-role-key'
```

3) Run the script

```bash
node tools/create_test_users.js
```

Notes:
- The script creates authentication users using the Supabase admin API and inserts a row into the `accounts` table.
- Keep your service role key secure. Do not commit it to source control.
