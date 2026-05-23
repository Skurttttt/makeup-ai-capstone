#!/usr/bin/env node
/**
 * create_test_users.js
 *
 * Creates test users in Supabase using a service role key and inserts
 * corresponding rows into the `accounts` table.
 *
 * Usage:
 * 1. Install dependencies: `npm install @supabase/supabase-js`
 * 2. Set env vars: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`
 * 3. Run: `node tools/create_test_users.js`
 *
 * The script prints created accounts and passwords to stdout.
 */

import { createClient } from '@supabase/supabase-js'

function genPassword(len = 12) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-='
  let out = ''
  for (let i = 0; i < len; i++) out += chars[Math.floor(Math.random() * chars.length)]
  return out
}

async function main() {
  const url = process.env.SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) {
    console.error('ERROR: Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.')
    process.exit(1)
  }

  const supabase = createClient(url, key, { auth: { persistSession: false } })

  // Define users to create
  const users = [
    { email: 'admin1+test@local.test', role: 'admin', full_name: 'Admin One' },
    { email: 'admin2+test@local.test', role: 'admin', full_name: 'Admin Two' },
    { email: 'staff1+test@local.test', role: 'staff', full_name: 'Staff One' },
    { email: 'staff2+test@local.test', role: 'staff', full_name: 'Staff Two' },
    { email: 'staff3+test@local.test', role: 'staff', full_name: 'Staff Three' },
  ]

  const results = []

  for (const u of users) {
    const password = genPassword(14)
    console.log(`Creating user ${u.email} (${u.role})`)
    try {
      // Create auth user (admin)
      const { data: created, error: createErr } = await supabase.auth.admin.createUser({
        email: u.email,
        password,
        email_confirm: true,
        user_metadata: { full_name: u.full_name, role: u.role },
      })
      if (createErr) throw createErr

      const userId = created.user?.id
      if (!userId) throw new Error('Failed to get created user id')

      // Insert into accounts table
      const accountRow = {
        user_id: userId,
        email: u.email,
        full_name: u.full_name,
        role: u.role,
        created_at: new Date().toISOString(),
      }

      const { error: insertErr } = await supabase.from('accounts').insert([accountRow])
      if (insertErr) throw insertErr

      results.push({ email: u.email, password, id: userId, role: u.role })
      console.log(`✓ Created ${u.email} (id=${userId})`)
    } catch (err) {
      console.error(`ERROR creating ${u.email}:`, err.message || err)
    }
  }

  console.log('\nSummary:')
  results.forEach(r => console.log(`${r.role}: ${r.email}  password: ${r.password}  id: ${r.id}`))
}

main().catch(e => { console.error(e); process.exit(1) })
