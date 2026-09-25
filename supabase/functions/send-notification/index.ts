import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { initializeApp, cert } from 'npm:firebase-admin/app'
import { getMessaging } from 'npm:firebase-admin/messaging'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Initialize Firebase Admin lazily to avoid cold start errors if already initialized
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
    const { target, title, message, data } = await req.json()

    // 1. Validate inputs
    if (!title || !message || !target) {
      throw new Error("Missing required parameters")
    }

    // 2. Initialize Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. Fetch all active subscriptions to determine paid/free users
    const { data: subs } = await supabaseClient
      .from('subscriptions')
      .select('user_id')
      .eq('status', 'Active')
      .gt('end_date', new Date().toISOString())

    const { data: paidProfiles } = await supabaseClient
      .from('profiles')
      .select('id')
      .gt('subscription_end_date', new Date().toISOString())

    const paidUserIds = new Set([
      ...(subs?.map((s) => s.user_id) || []),
      ...(paidProfiles?.map((p) => p.id) || [])
    ])

    // 4. Fetch FCM tokens
    const { data: tokensData, error: tokensError } = await supabaseClient
      .from('user_fcm_tokens')
      .select('user_id, token')

    if (tokensError) {
      throw new Error("Failed to fetch FCM tokens")
    }

    // 5. Filter tokens based on target
    let tokensToSend: string[] = []
    
    if (tokensData && tokensData.length > 0) {
      for (const t of tokensData) {
        if (!t.token) continue;
        
        const isPaid = paidUserIds.has(t.user_id)
        if (target === 'All Users') {
          tokensToSend.push(t.token)
        } else if (target === 'Paid Users' && isPaid) {
          tokensToSend.push(t.token)
        } else if (target === 'Free Users' && !isPaid) {
          tokensToSend.push(t.token)
        } else if (target === t.user_id) {
          tokensToSend.push(t.token)
        }
      }
    }

    // Deduplicate tokens
    tokensToSend = [...new Set(tokensToSend)]

    if (tokensToSend.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No matching users with push tokens." }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 6. Send via Firebase Admin
    getFirebaseApp(); // Initialize Firebase
    const messaging = getMessaging();

    // Firebase multicast allows up to 500 tokens per batch
    const BATCH_SIZE = 500;
    let successCount = 0;
    let failureCount = 0;

    for (let i = 0; i < tokensToSend.length; i += BATCH_SIZE) {
      const batchTokens = tokensToSend.slice(i, i + BATCH_SIZE);
      const payload: any = {
        notification: {
          title: title,
          body: message,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
        tokens: batchTokens,
      };

      if (data && typeof data === 'object') {
        payload.data = Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        );
      }

      const response = await messaging.sendEachForMulticast(payload);
      successCount += response.successCount;
      failureCount += response.failureCount;
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Notification sent to ${successCount} devices (Failed: ${failureCount})` 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error("Error sending notification:", error)
    return new Response(
      JSON.stringify({ error: error.message, stack: error.stack }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  }
})
