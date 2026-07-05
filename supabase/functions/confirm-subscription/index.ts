import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // ── 1. Authenticate the user ──
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const { checkout_id, plan_months } = await req.json()
    if (!checkout_id || !plan_months) throw new Error('checkout_id and plan_months are required')

    // ── 2. Verify the checkout is actually paid via Chargily API ──
    const CHARGILY_SECRET_KEY = Deno.env.get('CHARGILY_SECRET_KEY')
    if (!CHARGILY_SECRET_KEY) throw new Error('Chargily Secret Key not configured')

    const isTestMode = CHARGILY_SECRET_KEY.startsWith('test_')
    const apiBase = isTestMode
      ? 'https://pay.chargily.net/test/api/v2'
      : 'https://pay.chargily.net/api/v2'

    const verifyRes = await fetch(`${apiBase}/checkouts/${checkout_id}`, {
      headers: {
        'Authorization': `Bearer ${CHARGILY_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
    })

    if (!verifyRes.ok) {
      const errText = await verifyRes.text()
      console.error('Chargily verify error:', errText)
      throw new Error('Failed to verify checkout with Chargily')
    }

    const checkoutData = await verifyRes.json()

    if (checkoutData.status !== 'paid') {
      return new Response(
        JSON.stringify({ error: 'Checkout is not paid', status: checkoutData.status }),
        { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    // ── 3. Update subscription_end_date (service role) ──
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('subscription_end_date')
      .eq('id', user.id)
      .single()

    if (profileError) throw new Error(`Profile fetch error: ${profileError.message}`)

    const planMonthsInt = parseInt(plan_months.toString())
    let currentEndDate = new Date()

    if (profile.subscription_end_date) {
      const existingEnd = new Date(profile.subscription_end_date)
      if (existingEnd > currentEndDate) currentEndDate = existingEnd
    }

    const daysToAdd = planMonthsInt * 30
    currentEndDate.setDate(currentEndDate.getDate() + daysToAdd)
    const newEndDateISO = currentEndDate.toISOString()

    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({ subscription_end_date: newEndDateISO })
      .eq('id', user.id)

    if (updateError) throw new Error(`Profile update error: ${updateError.message}`)

    // ── 4. Record the transaction ──
    await supabaseAdmin.from('transactions').insert({
      user_id: user.id,
      type: 'purchase',
      amount: planMonthsInt,
      description: `Purchased ${planMonthsInt} Month(s) Subscription via Chargily Pay`,
    })

    console.log(`CONFIRM-SUB: Activated ${planMonthsInt} month(s) for user ${user.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        subscription_end_date: newEndDateISO,
        days_remaining: Math.ceil(
          (currentEndDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
        ),
      }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  } catch (error: any) {
    console.error('CONFIRM-SUB ERROR:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})
