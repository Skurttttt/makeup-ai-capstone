# Admin Editing & Real-time Subscription Sync - Quick Start Guide

## 🎯 What's New

Your app now has a **complete admin control system** where:
- Admins can edit user accounts (names, roles) from a professional web dashboard
- Admins can manage subscriptions (plans, status) for all users
- **Users see changes in real-time** on their subscription page
- Every admin action is **logged to the audit trail** for compliance

## 🚀 Getting Started

### Deploy the Schema (One-time setup)
Before anything works, you need to deploy the database schema:

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **SQL Editor**
4. Copy the entire contents of `database/schema.sql`
5. Paste into Supabase SQL Editor
6. Click **Run**

The schema includes:
- `accounts` table (user profiles with roles)
- `subscriptions` table (subscription plans and status)
- `audit_logs` table (admin action history)
- Real-time triggers for automatic updates

### Verify Installation

Run the app:
```bash
cd "c:\flutter projects\FaceTuneBeauty\makeup-ai-capstone"
flutter pub get
flutter run -d chrome  # For web admin
# OR
flutter run -d android  # For mobile
```

## 👥 Admin Dashboard

### Accessing the Admin Dashboard

**Web (Automatic):**
- Open app on web browser → Auto-routes to AdminScreenNew
- Shows professional admin interface with sidebar

**Mobile (Manual Navigation):**
- Login as admin user
- Should see bottom navigation with admin tabs

### Dashboard Sections

#### 📊 Dashboard Tab (Overview)
- KPI cards: Total Accounts, Active Subscriptions, Monthly Profit, Churn Rate
- Recent accounts list
- Quick stats overview

#### 👥 Accounts Tab (User Management)
**View All Users:**
- Click "Accounts" in sidebar
- See all users with: name, email, role, creation date

**Edit User Account:**
1. Find user in table
2. Click "Edit" button
3. Change:
   - **Full Name** - User's display name
   - **Role** - 'user' or 'admin'
4. Click "Save"
5. Admin action logged automatically
6. If user is logged in, they'll see their profile update

**Example workflow:**
```
Admin: Promotes user "John Doe" from 'user' to 'admin'
↓ (Real-time)
John Doe: If logged in, sees their role change in their account
Admin Logs: Records "john@email.com role changed: user → admin"
```

#### 💳 Subscriptions Tab (Subscription Management)
**View All Subscriptions:**
- Click "Subscriptions" in sidebar
- See all users' subscriptions with: email, plan, status, renewal date

**Edit User Subscription:**
1. Find subscription in table
2. Click "Edit" button
3. Change:
   - **Plan** - trial, pro, or premium
   - **Status** - active, trial, past_due, canceled, expired
4. Click "Save"
5. Admin action logged
6. User sees update immediately

**Example workflow:**
```
Admin: Changes "sarah@email.com" subscription from "trial" to "premium"
↓ (Real-time via PostgreSQL)
Sarah (if in app): Subscription page updates automatically
Shows: Premium badge, new renewal date
Admin Logs: Records "sarah@email.com plan changed: trial → premium"
```

#### 💰 Profit Tab
Placeholder for profit tracking (coming soon)

#### 📝 Audit Logs Tab
**View All Admin Actions:**
- Shows all changes made by admins
- Displays: Timestamp, Admin email, Action type, Target user, Change details
- Read-only for compliance/compliance tracking

## 👤 User Subscription View

### How Users See Their Subscriptions

Users can view their subscriptions in two places:

#### 1. Premium Tab (Home Screen)
- Shows subscription plans available
- Displays current active subscription
- Options to upgrade or cancel

#### 2. Via UserSubscriptionPage
- Shows all user's subscriptions
- Real-time status updates
- Can cancel subscription from here

### User Experience with Real-time Sync

**Scenario:**
Admin is viewing admin dashboard, user is viewing their subscription page.

```
Timeline:
00:00 - User opens "Premium" tab → Sees "Trial" subscription
00:05 - Admin upgrades user to "Premium" plan
00:06 - User's Premium tab updates automatically ✨
      Shows: "Premium" badge instead of "Trial"
      Shows: New renewal date
      Shows: Manage options for Premium plan
```

## 🔐 Security & Logging

### Audit Trail
Every admin action is logged with:
- **Who**: Admin email address
- **When**: Exact timestamp
- **What**: Action type (updated_account, updated_subscription)
- **Where**: Target user/subscription
- **How**: Old and new values stored in metadata

View logs in:
- Supabase Dashboard → Tables → audit_logs
- Admin Dashboard → Audit Logs tab

### Row-Level Security (RLS)
- Users can only see their own data
- Admins can see all data (via admin functions)
- All changes require authentication
- Database enforces security (not just frontend)

## 🔄 Real-time Sync Technical Details

### How It Works

1. **Admin makes change** (e.g., edits user role)
2. **Supabase updates database**
3. **PostgreSQL triggers** notify all connected clients
4. **User's app receives notification** (if subscribed)
5. **App refreshes UI automatically** (no manual refresh needed)

### Latency
- Typically **<100ms** from admin change to user seeing it
- Depends on network conditions
- Real-time channels auto-reconnect on disconnect

### Connection Management
- Real-time listeners set up when pages load
- Automatically cleaned up when pages close
- Reconnects automatically on network change

## 📱 Mobile vs Web Admin

### Web Admin Dashboard
- Best for managing multiple accounts
- Professional sidebar navigation
- Full DataTables for all sections
- Recommended for admins

### Mobile Admin Dashboard
- Bottom navigation tabs
- Touch-friendly buttons
- Same functionality as web
- Good for on-the-go admin tasks

## 🛠️ Troubleshooting

### Issue: Admin changes don't show for user

**Solution:**
1. Check if schema was deployed (`database/schema.sql`)
2. Verify user is viewing subscription page (not home)
3. Check Supabase real-time is enabled in project settings
4. Look at browser console (F12) for errors

### Issue: Audit logs show "System" actor

**Normal behavior** - means action wasn't from an admin. Only actual admin edits show admin email.

### Issue: Subscription page shows "No subscriptions"

**Expected** - if user has no active subscription yet. Admin must create one from subscriptions tab.

### Issue: Changes sync to some users but not others

**Solution:**
- Check if those users are logged in and viewing subscription page
- If not logged in, they won't receive real-time updates
- Updates will apply next time they log in (data is correct in database)

## 📚 Code Examples

### For Developers

**Update account from code:**
```dart
final supabase = SupabaseService();
await supabase.updateUserProfile(
  userId: 'user-id',
  updates: {
    'full_name': 'New Name',
    'role': 'admin',
  },
);

// Logged automatically
await supabase.logAdminAction(
  action: 'updated_account',
  target: 'user-email@example.com',
  metadata: {'old_role': 'user', 'new_role': 'admin'},
);
```

**Update subscription from code:**
```dart
await supabase.updateSubscription(
  subscriptionId: 'sub-id',
  updates: {
    'plan': 'premium',
    'status': 'active',
  },
);
```

**Listen to subscription changes:**
```dart
final channel = supabase.subscribeToSubscriptions(userId);
// Automatically updates UI when changes occur
```

## ✨ Features Summary

| Feature | Admin | User |
|---------|-------|------|
| Edit Account Names | ✅ | ❌ |
| Change User Roles | ✅ | ❌ |
| Manage Subscriptions | ✅ | ❌ |
| View Own Subscription | ✅ | ✅ |
| See Real-time Updates | ✅ | ✅ |
| View Audit Logs | ✅ | ❌ |
| Change Own Subscription | ❌ | ✅ |

## 🎓 Next Steps

1. **Test the system**:
   - Create two test accounts (one admin, one user)
   - Admin: Edit user's name → User should see it update
   - Admin: Change subscription → User should see it in real-time

2. **Set up payment** (future):
   - Connect Stripe or Paddle for subscriptions
   - Auto-update status when payment succeeds

3. **Add notifications** (future):
   - Push notifications when subscription changes
   - Email when subscription expires

4. **Build reports** (future):
   - Export audit logs as CSV
   - Revenue reports from profits table
   - User churn analysis

## 📞 Questions?

Check these files for more details:
- [ADMIN_EDITING_GUIDE.md](ADMIN_EDITING_GUIDE.md) - Complete feature documentation
- [database/schema.sql](database/schema.sql) - Database structure
- [lib/screens/admin_screen_new.dart](lib/screens/admin_screen_new.dart) - Admin UI code
- [lib/screens/user_subscription_page.dart](lib/screens/user_subscription_page.dart) - User subscription UI
