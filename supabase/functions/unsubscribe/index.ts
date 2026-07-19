import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const id = url.searchParams.get("id");

    if (!id) {
      return new Response("Geçersiz veya eksik bağlantı.", { status: 400 });
    }

    // Update the marketing_leads table to mark as unsubscribed
    const { error } = await supabase
      .from("marketing_leads")
      .update({ is_unsubscribed: true })
      .eq("id", id);

    if (error) {
      console.error("Unsubscribe error:", error);
      return new Response("İşlem sırasında bir hata oluştu.", { status: 500 });
    }

    // 302 Redirect to the success page on the website
    return new Response(null, {
      status: 302,
      headers: new Headers({
        "Location": "https://www.maligorus.com/unsubscribed.html",
      }),
    });

  } catch (error) {
    console.error("Server error:", error);
    return new Response("Sunucu hatası", { status: 500 });
  }
});
