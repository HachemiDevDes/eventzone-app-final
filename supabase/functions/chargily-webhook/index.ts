import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"

serve(async (req) => {
  try {
    // --- HMAC Signature Verification ---
    const CHARGILY_SECRET_KEY = Deno.env.get('CHARGILY_SECRET_KEY')
    if (!CHARGILY_SECRET_KEY) throw new Error('Chargily Secret Key not configured')

    const signature = req.headers.get('signature')
    const payload = await req.text()

    if (signature) {
      // Verify HMAC-SHA256 signature from Chargily
      const encoder = new TextEncoder()
      const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(CHARGILY_SECRET_KEY),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign']
      )
      const signatureBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(payload))
      const computedSignature = Array.from(new Uint8Array(signatureBuffer))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')

      if (computedSignature !== signature) {
        console.error('WEBHOOK: Invalid signature')
        return new Response(
          JSON.stringify({ error: 'Invalid signature' }),
          { status: 403, headers: { 'Content-Type': 'application/json' } }
        )
      }
    } else {
      console.warn('WEBHOOK: No signature header present — proceeding without verification')
    }

    // --- Process Event ---
    const event = JSON.parse(payload)

    if (event.type === 'checkout.paid') {
      const checkout = event.data
      const metadata = checkout.metadata

      let userId = null;
      let planMonthsRaw = null;

      if (Array.isArray(metadata)) {
        for (const item of metadata) {
          if (item.user_id) userId = item.user_id;
          if (item.plan_months) planMonthsRaw = item.plan_months;
        }
      } else if (metadata && typeof metadata === 'object') {
        userId = metadata.user_id;
        planMonthsRaw = metadata.plan_months;
      }

      if (userId && planMonthsRaw) {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        
        const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

        const { data: profile, error: profileError } = await supabase
          .from('profiles')
          .select('subscription_end_date')
          .eq('id', userId)
          .single()

        if (profileError) throw new Error(`Profile error: ${profileError.message}`)

        const planMonths = parseInt(planMonthsRaw.toString())
        let currentEndDate = new Date()
        
        if (profile.subscription_end_date) {
            const existingEnd = new Date(profile.subscription_end_date)
            if (existingEnd > currentEndDate) currentEndDate = existingEnd
        }
        
        // Treat each plan month as exactly 30 days
        const daysToAdd = planMonths * 30
        currentEndDate.setDate(currentEndDate.getDate() + daysToAdd)
        
        const { error: updateError } = await supabase
          .from('profiles')
          .update({ subscription_end_date: currentEndDate.toISOString() })
          .eq('id', userId)

        if (updateError) throw new Error(`Update error: ${updateError.message}`)

        const { error: insertError } = await supabase
          .from('transactions')
          .insert({
            user_id: userId,
            type: 'purchase',
            amount: planMonths,
            description: `Purchased ${planMonths} Month(s) Subscription via Chargily Pay`,
          })

        if (insertError) {
          throw new Error(`Insert error: ${insertError.message}`)
        }

        console.log(`WEBHOOK: Successfully processed ${planMonths} month(s) subscription for user ${userId}`)
      } else {
        console.warn('WEBHOOK: Missing userId or planMonths in metadata', metadata)
      }
    }

    return new Response(JSON.stringify({ received: true }), { headers: { 'Content-Type': 'application/json' } })

  } catch (error: any) {
    console.error("WEBHOOK FATAL ERROR: ", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
