import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const newTopicRules = `
Sen bir moderatörsün. Kullanıcı yeni bir konu açıyor. İçeriği şu iki kurala göre değerlendir:

KURAL 1 (UYGUNSUZ İÇERİK): Metin içinde küfür, hakaret, aşağılayıcı veya topluluk kurallarına aykırı bir kelime var mı?
- Eğer varsa, sadece "B" cevabını dön. Başka bir şey yazma.

KURAL 2 (KONU DIŞI): İçerik temiz ancak ekonomi, maliye, muhasebe, vergi, finans veya profesyonel gelişim konuları DIŞINDA MI?
- Eğer içerik maliye, muhasebe, vergi, finans, ekonomi alanlarıyla doğrudan ilgili DEĞİLSE, sadece "C" cevabını dön. Başka bir şey yazma.

Her şey kurallara uygunsa sadece "A" cevabını dön.
Tek bir harf ("A", "B", "C") dışında hiçbir şey yazma.
`;

const replyRules = `
Sen bir moderatörsün. Kullanıcı bir yoruma veya mesaja cevap yazıyor. İçeriği şu kurala göre değerlendir:

KURAL: Metin içinde küfür, hakaret, aşağılayıcı veya topluluk kurallarına aykırı bir ifade var mı?
- Eğer varsa, sadece "B" cevabını dön. Başka bir şey yazma.

Eğer içerik uygunsa sadece "A" cevabını dön.
Tek bir harf ("A", "B") dışında hiçbir şey yazma.
`;

const nameRules = `
Sen bir moderatörsün. Kullanıcı profil adı veya isim giriyor. İçeriği şu kurallara göre değerlendir:

KURAL 1: İsim veya unvan içinde küfür, hakaret, aşağılayıcı veya topluluk kurallarına aykırı bir kelime veya ifade var mı?
- Eğer varsa, sadece "B" cevabını dön. Başka bir şey yazma.

KURAL 2: İsim veya unvan içinde rakam, sayı veya geçersiz özel karakterler var mı (Örn: "Ahmet123", "Mehmet5")?
- Eğer varsa, sadece "B" cevabını dön. Başka bir şey yazma.

Eğer içerik kurallara uygunsa sadece "A" cevabını dön.
Tek bir harf ("A", "B") dışında hiçbir şey yazma.
`;

const profileImageRules = `
Sen bir moderatörsün. Kullanıcı profil resmi yüklüyor. İçeriği şu kurallara göre değerlendir:

KURAL 1: Görselde net bir şekilde bir insan kafası, insan yüzü veya insan figürü var mı?
- Eğer görselde hiçbir insan kafası veya insan yüzü YOKSA, sadece "B" cevabını dön. Başka bir şey yazma.

KURAL 2: Görselde küfür, hakaret, aşağılayıcı, müstehcen veya topluluk kurallarına aykırı bir durum var mı?
- Eğer varsa, sadece "B" cevabını dön. Başka bir şey yazma.

Eğer görselde bir insan kafası/yüzü varsa ve kurallara uygunsa sadece "A" cevabını dön.
Tek bir harf ("A", "B") dışında hiçbir şey yazma.
`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { text, image, mimeType, mode, is_new_topic } = await req.json()
    let rules = is_new_topic ? newTopicRules : replyRules
    if (mode === 'name') {
      rules = nameRules
    } else if (mode === 'image') {
      rules = profileImageRules
    }

    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) throw new Error('OPENAI_API_KEY bulunamadı!')

    let output = '';

    // A. Görsel/Resim Denetimi
    if (mode === 'image' && image) {
      const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openaiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: rules },
            {
              role: "user",
              content: [
                { type: "text", text: "Bu görseli denetle:" },
                { type: "image_url", image_url: { url: `data:${mimeType};base64,${image}`, detail: "low" } }
              ]
            }
          ],
          temperature: 0.0,
          max_tokens: 1
        })
      })

      if (openaiResponse.ok) {
        const data = await openaiResponse.json()
        output = data.choices?.[0]?.message?.content || 'A'
      } else {
        throw new Error(`OpenAI API Hatası (Status: ${openaiResponse.status})`)
      }
    } 
    // B. Metin Denetimi
    else {
      const label = mode === 'name' ? '[ISIM]' : '[METIN]';
      const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${openaiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: Deno.env.get('OPENAI_MODEL') || "gpt-4o-mini",
          messages: [
            { role: "system", content: rules },
            { role: "user", content: `Şu içeriği denetle ${label}: ${text}` }
          ],
          temperature: 0.0,
          max_tokens: 1
        })
      })

      if (openaiResponse.ok) {
        const data = await openaiResponse.json()
        output = data.choices?.[0]?.message?.content || 'A'
      } else {
        throw new Error(`OpenAI API Hatası (Status: ${openaiResponse.status})`)
      }
    }

    const cleanedOutput = output.trim().toUpperCase();
    let finalResult = 'ONAY';
    if (cleanedOutput.includes('B')) {
      finalResult = 'UYGUNSUZ_ICERIK';
    } else if (cleanedOutput.includes('C')) {
      finalResult = 'KONU_DISI';
    }

    return new Response(JSON.stringify({ result: finalResult }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    })
  }
})
