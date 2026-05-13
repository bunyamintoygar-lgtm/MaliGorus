import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from "npm:google-auth-library"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
  try {
    const payload = await req.json()
    const { record } = payload // Database webhook payload
    
    if (!record || !record.user_id) {
      return new Response(JSON.stringify({ error: 'Invalid payload' }), { status: 400 })
    }

    // 1. Get user tokens
    const { data: tokens, error: tokenError } = await supabase
      .from('fcm_tokens')
      .select('token')
      .eq('user_id', record.user_id)

    if (tokenError || !tokens || tokens.length === 0) {
      console.log(`No tokens found for user ${record.user_id}`)
      return new Response(JSON.stringify({ message: 'No tokens found' }), { status: 200 })
    }

    // 2. Get Access Token for FCM v1
    const accessToken = await getAccessToken(FIREBASE_SERVICE_ACCOUNT)

    // 3. Send notifications
    const results = await Promise.all(tokens.map(t => 
      sendFcmNotification(
        accessToken, 
        t.token, 
        record.title, 
        record.body, 
        record.data,
        record.image_url
      )
    ))

    // 4. Update queue status
    await supabase
      .from('notifications_queue')
      .update({ status: 'sent' })
      .eq('id', record.id)

    return new Response(JSON.stringify({ results }), { status: 200 })
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})

async function getAccessToken(serviceAccount: any) {
  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  return token.token;
}

async function sendFcmNotification(
  accessToken: string, 
  token: string, 
  title: string, 
  body: string, 
  data: any,
  image?: string
) {
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`
  
  const response = await fetch(fcmUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token: token,
        notification: { 
          title, 
          body,
          image: image || undefined 
        },
        data: {
          ...data,
          image_url: image || ""
        },
        android: {
          notification: {
            icon: "launcher_icon",
            color: "#1a237e"
          }
        },
      },
    }),
  })

  return response.json()
}
