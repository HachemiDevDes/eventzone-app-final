/**
 * Vercel Serverless Function: HubSpot OAuth Callback
 * 
 * This endpoint receives the temporary OAuth `code` from the Flutter frontend,
 * exchanges it securely with HubSpot for access & refresh tokens using the
 * hidden client_secret, and saves the tokens to the database.
 */

import type { VercelRequest, VercelResponse } from '@vercel/node';

// These should be set in your Vercel Project Environment Variables
const HUBSPOT_CLIENT_ID = process.env.HUBSPOT_CLIENT_ID;
const HUBSPOT_CLIENT_SECRET = process.env.HUBSPOT_CLIENT_SECRET;
const REDIRECT_URI = 'https://profile.eventzone.pro/oauth-callback'; // Must match exactly what was sent from Flutter app

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed. Use POST.' });
  }

  try {
    // 1. Extract the authorization code passed from the Flutter frontend
    const { code } = req.body;
    
    if (!code) {
      return res.status(400).json({ error: 'Missing authorization code in request body.' });
    }

    if (!HUBSPOT_CLIENT_ID || !HUBSPOT_CLIENT_SECRET) {
      console.error("Missing HubSpot credentials in Vercel environment.");
      return res.status(500).json({ error: 'Server configuration error.' });
    }

    // 2. Exchange the code for access & refresh tokens with HubSpot
    const tokenResponse = await fetch('https://api.hubapi.com/oauth/v1/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: HUBSPOT_CLIENT_ID,
        client_secret: HUBSPOT_CLIENT_SECRET,
        redirect_uri: REDIRECT_URI,
        code: code,
      }).toString(),
    });

    const tokenData = await tokenResponse.json();

    if (!tokenResponse.ok) {
      console.error('HubSpot Token Exchange Error:', tokenData);
      return res.status(tokenResponse.status).json({ 
        error: 'Failed to exchange token with HubSpot', 
        details: tokenData 
      });
    }

    const { access_token, refresh_token, expires_in } = tokenData;

    // 3. Mock Database Function: Save tokens to Supabase (or your DB) securely.
    // In production, you would extract the user's ID from an auth header (e.g., Supabase JWT)
    // passed along with this request from Flutter.
    const mockUserId = "user_12345"; 
    await saveToSupabase(mockUserId, access_token, refresh_token, expires_in);

    // 4. Return success to the Flutter frontend so it can dismiss the UI
    // We pass back the access_token so the frontend can immediately cache it if needed,
    // though ideally the frontend should just refetch its connection state from the DB.
    return res.status(200).json({ 
      success: true, 
      access_token: access_token 
    });

  } catch (error: any) {
    console.error('OAuth Callback Error:', error);
    return res.status(500).json({ error: 'Internal Server Error', message: error.message });
  }
}

/**
 * Placeholder function for saving tokens securely to your Supabase database.
 */
async function saveToSupabase(userId: string, accessToken: string, refreshToken: string, expiresIn: number) {
  console.log(`[DB Mock] Saving HubSpot tokens for user \${userId}`);
  console.log(`[DB Mock] Access Token (truncated): \${accessToken.substring(0, 5)}...`);
  console.log(`[DB Mock] Expires in: \${expiresIn} seconds`);
  
  // Example Supabase Implementation:
  /*
  import { createClient } from '@supabase/supabase-js'
  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  
  const { error } = await supabase
    .from('crm_connections')
    .upsert({
      user_id: userId,
      provider: 'hubspot',
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
    })
    
  if (error) throw new Error('Database Error: ' + error.message);
  */
}
