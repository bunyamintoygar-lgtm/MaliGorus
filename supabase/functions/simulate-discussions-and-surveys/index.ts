import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
  try {
    // 1. Rastgele bir bot kullanıcı seç
    const { data: bots, error: botError } = await supabase
      .from('profiles')
      .select('id, profession')
      .like('referral_code', 'YZ-%')

    if (botError || !bots || bots.length === 0) {
      throw new Error('Bot kullanıcı bulunamadı.')
    }

    const randomBot = bots[Math.floor(Math.random() * bots.length)]

    // 2. Anket ve Tartışma Geçmişini Çek (Tekrarı Önlemek İçin)
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString()
    
    // Son 2 gündeki tartışma/danışmaları çek
    const { data: recentDiscussions } = await supabase
      .from('discussions')
      .select('title')
      .gte('created_at', twoDaysAgo)
      .order('created_at', { ascending: false })
      .limit(20)

    let recentTitlesStr = "Yok"
    if (recentDiscussions && recentDiscussions.length > 0) {
      recentTitlesStr = recentDiscussions.map(d => d.title).join(" | ")
    }

    // Aktif anket durumunu kontrol et
    const { data: activeSurveys } = await supabase
      .from('surveys')
      .select('title')
      .eq('status', 'active')
      .gte('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(5)

    let recentSurveyTitles = "Yok"
    if (activeSurveys && activeSurveys.length > 0) {
      recentSurveyTitles = activeSurveys.map(s => s.title).join(" | ")
    }

    // 3. Aksiyon tipi seçimi
    const actionRandom = Math.random()
    let actionType = 'tartisma'
    
    // Eğer aktif anket hiç yoksa, anket üretimini zorla
    if (!activeSurveys || activeSurveys.length === 0) {
      actionType = 'survey'
    } else {
      // Normal oranlar (%20 anket, %10 danışma, %70 tartışma)
      if (actionRandom < 0.2) actionType = 'survey'
      else if (actionRandom < 0.3) actionType = 'danisma'
    }

    // 2.1 Kategorileri veritabanından çek (app_config tablosundan)
    const { data: configs } = await supabase
      .from('app_config')
      .select('key, value')
      .in('key', ['discussion_categories', 'consultation_categories'])

    let discCategoriesStr = '[]'
    let consCategoriesStr = '[]'

    if (configs) {
      const discConf = configs.find(c => c.key === 'discussion_categories')
      if (discConf) discCategoriesStr = JSON.stringify(discConf.value)
      
      const consConf = configs.find(c => c.key === 'consultation_categories')
      if (consConf) consCategoriesStr = JSON.stringify(consConf.value)
    }

    // 3. Deneyim Seviyesi Belirleme (Çeşitlilik İçin)
    // %20 Yeni başlayan, %30 Orta seviye, %50 Kıdemli
    const expRandom = Math.random()
    let experienceLevel = '10-15 yıllık kıdemli, çok tecrübeli ve profesyonel bir'
    if (expRandom < 0.2) {
      experienceLevel = 'mesleğe henüz 1-2 yıl önce başlamış, bazı konularda tecrübesiz, kafası kolay karışabilen genç bir'
    } else if (expRandom < 0.5) {
      experienceLevel = '4-5 yıllık orta düzey deneyimli bir'
    }

    // 4. Prompt Hazırlığı
    let prompt = ""
    if (actionType === 'survey') {
      prompt = `Sen ${experienceLevel} Türk ${randomBot.profession || 'Mali Müşavir'}sin. Meslektaşlarına soracağın, etkileşim alabilecek, güncel bir anket (anket sorusu) hazırla.
Kurallar:
- JSON formatında dön: {"title": "Anket Başlığı", "body": "Anketin net açıklaması (en fazla 1 kısa paragraf)", "category": "diger", "options": ["Seçenek 1", "Seçenek 2", "Seçenek 3"]}
- Seçenekler en az 2, en fazla 4 tane olsun.
- ÖNEMLİ: Son zamanlarda şu anketler açıldı: [${recentSurveyTitles}]. Yeni üreteceğin anket KESİNLİKLE bunlardan tamamen FARKLI bir konuda ve FARKLI bir kategoride olsun.
- KESİNLİKLE YAPAY ZEKA (AI, ChatGPT, robotik süreç otomasyonu vb.) konularında içerik üretme. Klasik ve pratik muhasebe sorunlarına, anketlerine odaklan.
- Doğal, insansı bir dil kullan.`
    } else if (actionType === 'danisma') {
      prompt = `Sen ${experienceLevel} Türk ${randomBot.profession || 'Muhasebe Uzmanı'}sın. Kendi ofisinde/şirketinde başından geçen spesifik ve zorlayıcı bir mükellef sorununu veya pratik bir çıkmazı meslektaşlarına danışacağın net bir soru (danışma) yaz.
Kurallar:
- Sadece JSON dön: {"title": "Gönderi Başlığı", "body": "Gönderi içeriği", "category": "secilen_kategori_key"}
- İçerik net ve öz olsun. Kesinlikle en fazla 1 kısa paragraftan oluşsun. Durumu gereksiz uzatmadan, doğrudan ve akıcı şekilde açıkla.
- Gönderi içeriğini (body) ve başlığını yazarken ara sıra doğal imla hataları ve klavye kayması (typo) hataları yap (örneğin de/da yazımlarında, büyük/küçük harf kullanımında, noktalama işaretlerinde veya harf atlamalarında hafif/doğal hatalar olsun).
- Gönderi başlığında (title) ve içeriğinde (body) KESİNLİKLE noktalı virgül (;) veya iki nokta üst üste (:) kullanma.
- Konu genel bir bilgi talebi değil, sana özel bir sıkıntı/problem olsun (örn: "Bugün ofise gelen bir mükellefim...", "Geçen ayki KDV beyannamesinde fark ettim ki...").
- KESİNLİKLE hiçbir gerçek veya kurgu firma adı / şirket ünvanı (Örn: X Ltd. Şti.) kullanma. Mükelleflerden anonim olarak bahset ("bir inşaat firması mükellefim", "bir şahıs şirketi" gibi).
- Kategori listesi (JSON formatında): ${consCategoriesStr}
- Yukarıdaki listeden içeriğe en uygun kategorinin ID veya KEY değerini "category" alanına yaz. Eğer uygun bir şey bulamazsan "diger" yaz.
- ÖNEMLİ: Son günlerde platformda şu konular konuşuldu: [${recentTitlesStr}]. Yeni üreteceğin içerik KESİNLİKLE bunlardan tamamen FARKLI bir konuda ve FARKLI bir kategoride olsun.
- KESİNLİKLE YAPAY ZEKA (AI, ChatGPT, robotik süreç otomasyonu vb.) konularında içerik üretme. Gerçek vergi, beyanname, SGK ve mükellef sorunlarına odaklan.
- Doğal, samimi, mesleki terimler içeren insansı bir dil kullan.`
    } else {
      prompt = `Sen ${experienceLevel} Türk ${randomBot.profession || 'Mali Müşavir'}sin. Meslektaşlarınla paylaşacağın, sektörel bir gelişme, mevzuat eleştirisi veya genel mesleki bir fikir beyanı (tartışma) yaz.
Kurallar:
- Sadece JSON dön: {"title": "Gönderi Başlığı", "body": "Gönderi içeriği", "category": "secilen_kategori_key"}
- İçerik net, öz ve vurucu olsun. Kesinlikle en fazla 1 kısa paragraftan oluşsun. Düşüncelerini gereksiz uzatmadan, doğrudan ifade et.
- Gönderi içeriğini (body) ve başlığını yazarken ara sıra doğal imla hataları ve klavye kayması (typo) hataları yap (örneğin de/da yazımlarında, büyük/küçük harf kullanımında, noktalama işaretlerinde veya harf atlamalarında hafif/doğal hatalar olsun).
- Gönderi başlığında (title) ve içeriğinde (body) KESİNLİKLE noktalı virgül (;) veya iki nokta üst üste (:) kullanma.
- Kategori listesi (JSON formatında): ${discCategoriesStr}
- Yukarıdaki listeden içeriğe en uygun kategorinin ID veya KEY değerini "category" alanına yaz. Eğer uygun bir şey bulamazsan "diger" yaz.
- ÖNEMLİ: Son günlerde platformda şu konular konuşuldu: [${recentTitlesStr}]. Yeni üreteceğin içerik KESİNLİKLE bunlardan tamamen FARKLI bir konuda ve FARKLI bir kategoride olsun.
- KESİNLİKLE YAPAY ZEKA (AI, ChatGPT, robotik süreç otomasyonu vb.) konularında içerik üretme. Sektörel mevzuat, meslek sorunları, KDV/Gelir Vergisi oranları, e-beyanname sistemleri gibi klasik/güncel konulara odaklan.
- Doğal, samimi ve fikir belirten insansı bir dil kullan.`
    }

    // 4. OpenAI ile içerik üret
    const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-5.4-mini",
        messages: [
          { role: "user", content: prompt }
        ],
        temperature: 0.9,
      })
    })

    if (!openaiResponse.ok) {
      throw new Error(`OpenAI API Hatası: ${openaiResponse.statusText}`)
    }

    const data = await openaiResponse.json()
    let content = data.choices[0].message.content.trim()

    // Clean markdown code blocks if any
    if (content.startsWith('```json')) {
      content = content.replace(/^```json\n/, '').replace(/\n```$/, '')
    } else if (content.startsWith('```')) {
      content = content.replace(/^```\n/, '').replace(/\n```$/, '')
    }

    const parsedContent = JSON.parse(content)
    const finalCategory = parsedContent.category || 'diger'

    // 5. İçeriği Veritabanına Ekle
    if (actionType === 'survey') {
      // Flutter uygulamasındaki SurveyOption.fromJson modeline uyum sağlamak için 
      // [string, string...] yapısını [{"id": "...", "text": "...", "votes": 0}] yapısına çeviriyoruz.
      const formattedOptions = (parsedContent.options || []).map((opt: string, index: number) => ({
        id: crypto.randomUUID(),
        text: opt,
        votes: 0
      }))

      const { error: surveyError } = await supabase
        .from('surveys')
        .insert({
          author_id: randomBot.id,
          title: parsedContent.title,
          description: parsedContent.body,
          options: formattedOptions,
          status: 'active',
          expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
        })

      if (surveyError) throw surveyError
      console.log(`Yeni Anket oluşturuldu: ${parsedContent.title}`)

    } else {
      const { error: insertError } = await supabase
        .from('discussions')
        .insert({
          author_id: randomBot.id,
          type: actionType, // 'tartisma' veya 'danisma'
          category: finalCategory,
          title: parsedContent.title,
          body: parsedContent.body,
          visibility_type: 'everyone',
          status: 'active'
        })

      if (insertError) throw insertError
      console.log(`Yeni ${actionType} oluşturuldu: ${parsedContent.title} (Kategori: ${finalCategory})`)
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 })
  } catch (error) {
    console.error('Simülasyon hatası:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
