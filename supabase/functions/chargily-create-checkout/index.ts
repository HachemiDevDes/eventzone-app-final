import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' } })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const { amount, plan_months, promo_code } = await req.json()
    if (!amount || !plan_months) throw new Error('Amount and plan_months are required')

    let finalAmount = amount
    let appliedPromoCode = null

    if (promo_code) {
      const { data: promoData, error: promoError } = await supabaseClient
        .from('promo_codes')
        .select('code, discount_percentage')
        .eq('code', promo_code.toString().trim())
        .eq('is_active', true)
        .maybeSingle()

      if (promoError || !promoData) {
        throw new Error('Invalid or inactive promo code')
      }

      appliedPromoCode = promoData.code
      const discount = finalAmount * (promoData.discount_percentage / 100)
      finalAmount = Math.max(100, Math.round(finalAmount - discount)) // Ensure amount meets minimum requirement
    }

    const CHARGILY_SECRET_KEY = Deno.env.get('CHARGILY_SECRET_KEY')
    if (!CHARGILY_SECRET_KEY) throw new Error('Chargily Secret Key not configured')

    const isTestMode = CHARGILY_SECRET_KEY.startsWith('test_')
    const apiUrl = isTestMode 
        ? 'https://pay.chargily.net/test/api/v2/checkouts'
        : 'https://pay.chargily.net/api/v2/checkouts'

    // Create checkout in Chargily
    const chargilyRes = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${CHARGILY_SECRET_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        amount: finalAmount,
        currency: 'dzd',
        success_url: 'https://eventzone.pro/payment/success',
        failure_url: 'https://eventzone.pro/payment/failure',
        webhook_endpoint: 'https://awkreadldqmidcrrqukm.supabase.co/functions/v1/chargily-webhook',
        metadata: [
          { user_id: user.id },
          { plan_months: plan_months },
          ...(appliedPromoCode ? [{ promo_code: appliedPromoCode }] : [])
        ]
      })
    })

    if (!chargilyRes.ok) {
      const errorText = await chargilyRes.text()
      console.error('Chargily API Error:', errorText)
      throw new Error(`Failed to create Chargily checkout: ${errorText}`)
    }

    const chargilyData = await chargilyRes.json()
    
    return new Response(
      JSON.stringify(chargilyData),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  }
})
