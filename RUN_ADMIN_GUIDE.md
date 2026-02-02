// RUN ADMIN SIDE - COMPLETE GUIDE

## 🚀 Quick Start: Test Admin Dashboard

### Step 1: Create Admin User

**Option A: Via Signup (Recommended)**
1. Open app and click "Sign Up"
2. Fill in:
   - Full Name: Admin User
   - Email: admin@example.com
   - Password: Admin123
3. Click "Create Account"
4. You'll be logged in as a regular user

**Option B: Via Supabase (Manual)**
1. Go to Supabase → Authentication
2. Click "Add user"
3. Email: admin@example.com
4. Password: Admin123
5. Click "Create user"

### Step 2: Make User an Admin

In Supabase → SQL Editor → Run:
```sql
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'admin@example.com';
```

### Step 3: Test Admin Login

1. **Log out** from the app (if logged in)
2. Click "Sign In"
3. Enter:
   - Email: admin@example.com
   - Password: Admin123
4. Click "Sign In"
5. **Should now see AdminScreen! ✅**

---

## 📊 Admin Dashboard Features

The admin dashboard has 4 tabs:

### 1. **Dashboard Tab**
- Total Users card
- Active Scans card
- Revenue card
- Support Tickets card
- Recent Activity feed

### 2. **Users Tab**
- List of all users
- User status (Active/Premium/Inactive)
- User email and name
- Action buttons

### 3. **Analytics Tab**
- Daily Active Users graph
- Top Features Used stats
- Face Scan usage (85%)
- Makeup Tutorial usage (72%)
- Product Marketplace usage (58%)
- Premium Subscription usage (45%)

### 4. **Settings Tab**
- Push Notifications toggle
- Two-Factor Auth toggle
- Backup Data button
- Clear Cache button

---

## 🧪 Test All Features

### Test Dashboard Stats:
1. Login as admin
2. See 4 stat cards (Users, Scans, Revenue, Tickets)
3. Scroll down to see Recent Activity

### Test Users Tab:
1. Click "Users" at bottom
2. See list of all registered users
3. View status chips (Active/Premium/Inactive)

### Test Analytics:
1. Click "Analytics" at bottom
2. See Daily Active Users bar chart (Mon-Sun)
3. See Top Features Used progress bars

### Test Settings:
1. Click "Settings" at bottom
2. Toggle switches work
3. Buttons are clickable

### Test Logout:
1. Click logout icon (top right)
2. Confirm logout dialog
3. Should return to LoginSupabasePage

---

## 📱 Admin Credentials

```
Email: admin@example.com
Password: Admin123
Role: admin
```

---

## 🔧 Troubleshooting

### "Access Denied" / Goes to HomeScreen instead of AdminScreen
→ Check role was set to 'admin' in database
→ Run: `SELECT role FROM public.profiles WHERE email = 'admin@example.com';`
→ Should show: `admin`

### Can't see admin user in Users list
→ Check user was created in auth.users
→ Check profile exists in public.profiles
→ Run: `SELECT * FROM public.profiles;`

### Analytics showing 0 users/scans
→ This is expected if no actual users registered yet
→ The mock data in dashboard is hardcoded for demo

---

## 📊 See Real Data

To see real users in Admin:
1. Create multiple user accounts via signup
2. Login as admin
3. Go to Users tab
4. Should see all users listed

To see real scans (future):
1. Regular user takes a face scan
2. Scan saved to database
3. Admin analytics updates

---

## ✅ Admin Features Ready:

✅ Role-based authentication
✅ Admin-only login routing
✅ 4-tab admin dashboard
✅ User management view
✅ Analytics dashboard
✅ Admin settings panel
✅ Logout functionality
✅ Error handling

---

## 🎯 Next Steps

1. **Test Admin Signup**
   - Sign up as admin@example.com
   
2. **Promote to Admin**
   - Run SQL to set role = 'admin'
   
3. **Login as Admin**
   - Should see AdminScreen
   
4. **Explore Features**
   - Check all 4 tabs
   - Test navigation
   
5. **Create Regular Users**
   - Sign up with other emails
   - They'll see HomeScreen (not AdminScreen)

---

## 💡 Admin vs User Flows

**ADMIN LOGIN:**
```
Email: admin@example.com
Password: Admin123
         ↓
     AuthService checks role
         ↓
    role = 'admin'
         ↓
  Routes to AdminScreen ✅
```

**USER LOGIN:**
```
Email: user@example.com
Password: User123
         ↓
     AuthService checks role
         ↓
    role = 'user'
         ↓
  Routes to HomeScreen ✅
```

Everything is ready! Just follow the steps above and you'll have the admin side running! 🎉
