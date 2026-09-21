import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const token = body.token

    if (!token || typeof token !== 'string' || token.trim().length < 4) {
      return new Response(
        JSON.stringify({ error: 'Invalid or missing code' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'https://gknglowozpewwrtjumuc.supabase.co'
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!serviceRoleKey) {
      console.error('SUPABASE_SERVICE_ROLE_KEY is missing')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    // 1. Look up profile by crm_token
    const cleanToken = token.trim().toUpperCase()
    const { data: profile, error: profileError } = await adminClient
      .from('profiles')
      .select('id, email')
      .eq('crm_token', cleanToken)
      .maybeSingle()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired login code' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Fetch or auto-provision auth user
    let user: any = null
    const { data: userData, error: userError } = await adminClient.auth.admin.getUserById(profile.id)
    if (userData?.user) {
      user = userData.user
    } else if (profile.email) {
      // Auto-provision auth user with matching profile id so user can log in immediately
      const { data: createdData, error: createError } = await adminClient.auth.admin.createUser({
        id: profile.id,
        email: profile.email,
        email_confirm: true,
      })
      if (!createError && createdData?.user) {
        user = createdData.user
      } else {
        console.error('createUser error:', createError)
      }
    }

    if (!user || !user.email) {
      return new Response(
        JSON.stringify({ error: 'User account not found', details: userError?.message }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Generate link to get hashed_token
    const { data: linkData, error: linkError } = await adminClient.auth.admin.generateLink({
      type: 'magiclink',
      email: user.email,
    })

    if (linkError || !linkData?.properties?.hashed_token) {
      console.error('generateLink error:', linkError)
      return new Response(
        JSON.stringify({ error: linkError?.message || 'Could not generate token' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Verify token hash on server to get real access_token and refresh_token
    const { data: verifyData, error: verifyError } = await adminClient.auth.verifyOtp({
      token_hash: linkData.properties.hashed_token,
      type: 'magiclink',
    })

    if (verifyError || !verifyData?.session) {
      console.error('verifyOtp error:', verifyError)
      return new Response(
        JSON.stringify({ error: verifyError?.message || 'Could not create session' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 5. Return direct session tokens to frontend
    return new Response(
      JSON.stringify({
        type: 'session',
        access_token: verifyData.session.access_token,
        refresh_token: verifyData.session.refresh_token,
        user: {
          id: user.id,
          email: user.email,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('crm-token-auth error:', error)
    return new Response(
      JSON.stringify({ error: error?.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
