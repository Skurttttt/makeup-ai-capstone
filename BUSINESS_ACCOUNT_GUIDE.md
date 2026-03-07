# Business Account Setup Guide for FaceTune Beauty

## Overview
FaceTune Beauty now supports business accounts for makeup brands, salons, makeup artists, distributors, and retailers. This guide explains the new features and how to manage business accounts.

## What's New

### 1. **Dual Account Type Registration**
Users can now choose between two account types during signup:
- **Individual User**: Standard user account for trying makeup looks
- **Business Account**: Specialized account for makeup-related businesses

### 2. **Login Client Selection**
On login, users select whether they're logging in as:
- An individual user
- A business/makeup brand

### 3. **Business Information Collection**
When signing up for a business account, the following information is collected:

#### Required Fields:
- **Business Name**: Name of the makeup business/brand
- **Business Type**: Category of business (see types below)
- **Business Phone**: Contact phone number
- **Business Address**: Physical location of the business

#### Optional Fields:
- **Business Description**: About the business and offerings
- **Business Registration Number**: Business license/registration ID
- **Business Logo**: Logo image (added later in profile)

#### Business Types:
1. **Makeup Brand** - Cosmetics product manufacturer or brand
2. **Salon/Makeup Studio** - Beauty salon or makeup service provider
3. **Makeup Artist** - Professional makeup artist
4. **Distributor** - Wholesale or distribution business
5. **Retailer** - Retail store selling makeup products
6. **Other** - Other makeup-related businesses

## Database Schema

### New Columns in `accounts` Table:
```
account_type TEXT - 'individual' or 'business'
client_type TEXT - Login client type: 'individual' or 'business'
business_name TEXT - Name of the business
business_type TEXT - Type of business
business_phone TEXT - Contact phone
business_address TEXT - Business address (up to 2 lines)
business_description TEXT - Business description (up to 3 lines)
business_reg_number TEXT - Registration/license number
business_logo_url TEXT - URL to logo image
business_verified BOOLEAN - Admin verification status
business_verified_at TIMESTAMP - Verification timestamp
```

### Indexes Added:
- `idx_accounts_business_type` - For querying by business type
- `idx_accounts_account_type` - For querying by account type

## Signup Flow (Business Account)

1. User selects "Business" account type
2. User enters personal details:
   - Full Name (owner/representative name)
   - Email
   - Password
3. User enters business information:
   - Business Name
   - Business Type (dropdown selection)
   - Phone Number
   - Address
   - Description (optional)
   - Registration Number (optional)
4. System stores all information in `accounts` table
5. User verifies email address
6. Business account is created with default `business_verified = false`

## Signup Flow (Individual Account)

1. User selects "Individual" account type
2. User enters personal details:
   - Full Name
   - Email
   - Password
3. Business fields are hidden
4. User verifies email
5. Regular user account is created

## Login Flow

1. User enters email and password
2. User selects client type:
   - Individual User (standard)
   - Business/Makeup Brand (if account supports business)
3. System validates credentials and client type selection
4. `client_type` is updated in user profile if business selected
5. User is routed to appropriate dashboard

## Admin Management

### Features for Admin:
- View all business account registrations
- Verify/approve business accounts
- Review business information (name, type, address, reg number)
- Approve or reject business registrations
- View business account status and verified date
- Manage business account permissions

### Access Business Accounts:
Admins should access business accounts through:
- Business account management dashboard
- Verification workflow for new businesses
- Business profile editing tools

## Features Enabled for Verified Businesses:
- Marketplace listing (planned)
- Product showcase (planned)
- Customer management (planned)
- Analytics dashboard (planned)
- Direct messaging with customers (planned)

## Security & RLS Policies

All business information is protected by Row Level Security (RLS):
- Users can only view/edit their own business information
- Admins can view and manage all business accounts
- Business verification is admin-only

## API/Data Updates

When a user signs up with a business account, the auth.signUp() data includes:
```dart
data: {
  'full_name': 'John Doe',
  'account_type': 'business',
  'business_name': 'Glamour Cosmetics',
  'business_type': 'makeup_brand',
  'business_phone': '+1 (555) 123-4567',
  'business_address': '123 Main St, City, State 12345',
  'business_description': 'Premium makeup products...',
  'business_reg_number': 'REG-123456'
}
```

## Migration Instructions

To add business account support to existing database:

1. Run the migration file:
   ```sql
   -- database/add_business_fields_migration.sql
   ```

2. Or run the complete updated schema:
   ```sql
   -- database/schema.sql (updated version)
   ```

3. Set up admin dashboard for business verification (manual setup required)

## Future Enhancements

- [ ] Business profile completion percentage
- [ ] Business email verification
- [ ] Business document upload for verification
- [ ] Subscription plans for businesses
- [ ] Business marketplace/storefront
- [ ] Product catalog management
- [ ] Customer reviews and ratings for businesses
- [ ] Business analytics and reporting

## Troubleshooting

### Business fields not appearing in signup?
- Clear app cache and reload
- Ensure business account type is selected
- Check that all validators are working

### Business information not saving?
- Verify all required fields are filled
- Check database constraints and RLS policies
- Review Supabase logs for errors

### Login not updating client_type?
- Ensure selection is made before login
- Check that query to update `accounts` table succeeds
- Verify user has permission to update their own account

## Contact & Support

For questions about business account features, contact:
- Admin Email: admin@facetunebeauty.com
- Business Support: business@facetunebeauty.com
