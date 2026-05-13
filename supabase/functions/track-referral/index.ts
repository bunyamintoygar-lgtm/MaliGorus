import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS handling
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    const fingerprint = await req.json()
    
    // IP adresini yakala (x-forwarded-for header'ından)
    const ip = req.headers.get('x-forwarded-for')?.split(',')[0] || 'unknown'

    const { error } = await supabase
      .from('referral_clicks')
      .insert({
        ref_code: fingerprint.refCode,
        ip_address: ip,
        user_agent: fingerprint.userAgent,
        screen_res: fingerprint.screenRes,
        pixel_ratio: fingerprint.pixelRatio,
        timezone: fingerprint.timezone,
        platform: fingerprint.platform,
        language: fingerprint.language
      })

    if (error) throw error

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
