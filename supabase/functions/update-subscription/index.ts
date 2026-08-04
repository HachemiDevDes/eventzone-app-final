import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }})
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json()
    const { userId, newEndDate, tier, status } = body

    if (!userId || !newEndDate) {
      return new Response(JSON.stringify({ error: 'Missing userId or newEndDate' }), { status: 400 })
    }

    // 1. Update subscriptions table
    const { data: existingSub, error: fetchErr } = await supabaseClient
      .from('subscriptions')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle()
      
    if (fetchErr) throw new Error('Fetch Sub Error: ' + fetchErr.message)

    if (existingSub) {
      const { error: updateErr } = await supabaseClient
        .from('subscriptions')
        .update({
          end_date: newEndDate,
          tier: tier || 'Pro',
          status: status || 'Active',
          updated_at: new Date().toISOString()
        })
        .eq('id', existingSub.id)
      if (updateErr) throw new Error('Update Sub Error: ' + updateErr.message)
    } else {
      const { error: insertErr } = await supabaseClient
        .from('subscriptions')
        .insert({
          user_id: userId,
          tier: tier || 'Pro',
          status: status || 'Active',
          start_date: new Date().toISOString(),
          end_date: newEndDate,
          interval: 'Monthly'
        })
      if (insertErr) throw new Error('Insert Sub Error: ' + insertErr.message)
    }

    // 2. Update profiles table
    const { error: profileErr } = await supabaseClient
      .from('profiles')
      .update({ subscription_end_date: newEndDate })
      .eq('id', userId)
      
    if (profileErr) throw new Error('Update Profile Error: ' + profileErr.message)

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      status: 400,
    })
  }
})
