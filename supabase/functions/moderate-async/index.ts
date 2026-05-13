import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

const replyRules = `
Sen bir moderatörsün. Kullanıcı bir yoruma veya mesaja cevap yazıyor. İçeriği şu kurala göre değerlendir:

KURAL: Metin içinde küfür, hakaret, aşağılayıcı veya topluluk kurallarına aykırı bir ifade var mı?
- Eğer varsa, sadece "B" cevabını dön. Başka bir şey yazma.

Eğer içerik uygunsa sadece "A" cevabını dön.
Tek bir harf ("A", "B") dışında hiçbir şey yazma.
`;

serve(async (req) => {
  try {
    const payload = await req.json()
    const { record } = payload

    if (!record || !record.id || !record.body) {
      return new Response(JSON.stringify({ error: "Invalid webhook payload" }), { status: 400 })
    }

    // OpenAI API çağrısı yaparak mesajı denetliyoruz
    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: replyRules },
          { role: "user", content: `Şu içeriği denetle: ${record.body}` }
        ],
        temperature: 0.0,
        max_tokens: 1
      })
    })

    if (!openaiResponse.ok) {
      throw new Error(`OpenAI API Hatası (Status: ${openaiResponse.status})`)
    }

    const data = await openaiResponse.json()
    const output = data.choices?.[0]?.message?.content || 'A'
    const cleanedOutput = output.trim().toUpperCase()

    // Eğer uygunsuz içerik tespit edilmişse
    if (cleanedOutput.includes('B')) {
      // 1. Olası yasal süreçler için orijinal mesajı arşiv tablosuna kaydediyoruz
      await supabase
        .from('moderated_messages_archive')
        .insert({
          message_id: record.id,
          sender_id: record.sender_id,
          receiver_id: record.receiver_id,
          original_body: record.body
        })

      // 2. Mesajın içeriğini maskeliyoruz
      await supabase
        .from('messages')
        .update({ body: '*** (Bu mesaj kurallara aykırı olduğu için gizlenmiştir)' })
        .eq('id', record.id)

      // 3. Bu mesajla ilgili gönderilmek üzere sırada bekleyen bildirimi siliyoruz
      await supabase
        .from('notifications_queue')
        .delete()
        .eq('user_id', record.receiver_id)
        .eq('body', record.body)

      console.log(`Uygunsuz mesaj tespit edildi, arşivlendi ve engellendi (ID: ${record.id})`)
    } else {
      console.log(`Mesaj temiz, onaylandı (ID: ${record.id})`)
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 })
  } catch (error) {
    console.error('Asenkron moderasyon hatası:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
