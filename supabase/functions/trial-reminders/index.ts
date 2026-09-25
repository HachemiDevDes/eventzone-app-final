import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { initializeApp, cert } from 'npm:firebase-admin/app'
import { getMessaging } from 'npm:firebase-admin/messaging'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

let firebaseApp: any = null;
function getFirebaseApp() {
  if (!firebaseApp) {
    // Option 1: Full JSON string in FIREBASE_SERVICE_ACCOUNT or FIREBASE_SERVICE_ACCOUNT_KEY
    const rawJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY');
    if (rawJson && rawJson.trim()) {
      try {
        const parsed = typeof rawJson === 'string' ? JSON.parse(rawJson.trim()) : rawJson;
        firebaseApp = initializeApp({
          credential: cert(parsed),
        });
        return firebaseApp;
      } catch (err: any) {
        console.error("Failed to parse FIREBASE_SERVICE_ACCOUNT JSON:", err);
      }
    }

    // Option 2: Individual environment variables
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID') || 'eventzone-app-f4984';
    const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL');
    const rawPrivateKey = Deno.env.get('FIREBASE_PRIVATE_KEY');

    if (!clientEmail || !rawPrivateKey) {
      throw new Error(
        "Firebase Admin credentials are missing. Please add FIREBASE_SERVICE_ACCOUNT (full service account JSON from Firebase Console) in Supabase Dashboard -> Project Settings -> Edge Functions -> Secrets."
      );
    }

    const privateKey = rawPrivateKey.replace(/\\n/g, '\n');
    firebaseApp = initializeApp({
      credential: cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  }
  return firebaseApp;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const today = new Date()
    
    // Find exact dates for 7 days and 1 day from now
    const sevenDaysFromNow = new Date(today)
    sevenDaysFromNow.setDate(today.getDate() + 7)
    const sevenDaysString = sevenDaysFromNow.toISOString().split('T')[0]
    
    const oneDayFromNow = new Date(today)
    oneDayFromNow.setDate(today.getDate() + 1)
    const oneDayString = oneDayFromNow.toISOString().split('T')[0]

    // 1. Fetch active paid subscriptions to skip those users
    const { data: subs } = await supabaseClient
      .from('subscriptions')
      .select('user_id')
      .eq('status', 'Active')
      .gt('end_date', today.toISOString())
    
    const paidUserIds = new Set(subs?.map((s) => s.user_id) || [])

    // 2. Query profiles whose trial ends in 7 days or 1 day
    const { data: profiles, error: pError } = await supabaseClient
      .from('profiles')
      .select('id, subscription_end_date')
      .not('subscription_end_date', 'is', null)

    if (pError) throw pError

    const users7Days: string[] = []
    const users1Day: string[] = []

    for (const profile of profiles || []) {
      if (paidUserIds.has(profile.id)) continue;
      
      const endDateString = profile.subscription_end_date.split('T')[0]
      if (endDateString === sevenDaysString) {
        users7Days.push(profile.id)
      } else if (endDateString === oneDayString) {
        users1Day.push(profile.id)
      }
    }

    if (users7Days.length === 0 && users1Day.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No trials expiring in 7 or 1 days.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 3. Fetch FCM tokens for these users
    const allIds = [...users7Days, ...users1Day]
    const { data: tokensData } = await supabaseClient
      .from('user_fcm_tokens')
      .select('user_id, token')
      .in('user_id', allIds)

    if (!tokensData || tokensData.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'Eligible users found but no FCM tokens available.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const tokens7Days: string[] = []
    const tokens1Day: string[] = []

    for (const t of tokensData) {
      if (!t.token) continue
      if (users7Days.includes(t.user_id)) {
        tokens7Days.push(t.token)
      } else if (users1Day.includes(t.user_id)) {
        tokens1Day.push(t.token)
      }
    }

    // 4. Send Notifications via Firebase
    getFirebaseApp()
    const messaging = getMessaging()
    
    let totalSent = 0
    let totalFailed = 0

    if (tokens7Days.length > 0) {
      const payload7 = {
        notification: {
          title: "Trial Ending Soon",
          body: "Your free trial ends in 7 days! Subscribe now to keep enjoying Eventzone without interruptions.",
        },
        tokens: [...new Set(tokens7Days)],
      }
      const r = await messaging.sendEachForMulticast(payload7)
      totalSent += r.successCount
      totalFailed += r.failureCount
    }

    if (tokens1Day.length > 0) {
      const payload1 = {
        notification: {
          title: "Trial Ends Tomorrow!",
          body: "Your free trial ends tomorrow! Activate your subscription to stay connected.",
        },
        tokens: [...new Set(tokens1Day)],
      }
      const r = await messaging.sendEachForMulticast(payload1)
      totalSent += r.successCount
      totalFailed += r.failureCount
    }

    return new Response(JSON.stringify({ success: true, message: `Sent ${totalSent} reminders (Failed: ${totalFailed}).` }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (error: any) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 })
  }
})
