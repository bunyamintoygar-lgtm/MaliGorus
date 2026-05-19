import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
  try {
    // 1. Tüm botları al
    const { data: bots, error: botError } = await supabase
      .from('profiles')
      .select('id, profession, full_name')
      .like('referral_code', 'YZ-%')

    if (botError || !bots || bots.length === 0) {
      throw new Error('Bot kullanıcı bulunamadı.')
    }
    const botIds = bots.map(b => b.id)

    const now = new Date()
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000).toISOString()
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString()

    // 2. Botlara gelmiş ama henüz botun okumadığı (is_read: false) ve zaman aralığındaki (1 saat ile 24 saat arası) mesajları bul
    const { data: recentMessages, error: msgError } = await supabase
      .from('messages')
      .select('*')
      .in('receiver_id', botIds)
      .eq('is_read', false)
      .gte('created_at', twentyFourHoursAgo)
      .lte('created_at', oneHourAgo)
      .order('created_at', { ascending: false })
      .limit(100)

    if (msgError || !recentMessages) throw msgError

    // Botun cevap vermediği mesajları filtrele
    const messagesToReply = []
    
    for (const msg of recentMessages) {
      // Gönderen kişi bot mu? Botlar kendi aralarında konuşmasın
      if (botIds.includes(msg.sender_id)) continue

      messagesToReply.push(msg)
    }

    if (messagesToReply.length === 0) {
      return new Response(JSON.stringify({ message: "Cevaplanacak mesaj yok." }), { status: 200 })
    }

    // İlk 3 mesaja cevap verelim (Spam olmaması için limitleme)
    const targets = messagesToReply.slice(0, 3)

    for (const msg of targets) {
      const bot = bots.find(b => b.id === msg.receiver_id)
      
      // Bot ve bu kullanıcı arasındaki en son 50 mesajlaşma geçmişini (arşivi) çekelim
      const { data: conversationHistory } = await supabase
        .from('messages')
        .select('sender_id, receiver_id, body, created_at')
        .or(`and(sender_id.eq.${msg.sender_id},receiver_id.eq.${msg.receiver_id}),and(sender_id.eq.${msg.receiver_id},receiver_id.eq.${msg.sender_id})`)
        .order('created_at', { ascending: false }) // En son atılan mesajları almak için DESCENDING
        .limit(50)

      let historyStr = ""
      if (conversationHistory && conversationHistory.length > 0) {
        // Mesajları kronolojik sırayla (eskiden yeniye) OpenAI'a sunmak için diziyi tersine çeviriyoruz
        const chronologicalHistory = [...conversationHistory].reverse()
        historyStr = chronologicalHistory.map((m: any) => {
          const senderLabel = m.sender_id === msg.sender_id ? "Meslektaş" : bot.full_name
          return `${senderLabel}: ${m.body}`
        }).join("\n")
      } else {
        historyStr = `Meslektaş: ${msg.body}`
      }

      // Türkiye saatine göre tarihi ve gün bilgisini alalım
      const formatter = new Intl.DateTimeFormat('tr-TR', {
        timeZone: 'Europe/Istanbul',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        weekday: 'long'
      })
      const currentDateStr = formatter.format(new Date())
      
      const istanbulDayStr = new Intl.DateTimeFormat('tr-TR', {
        timeZone: 'Europe/Istanbul',
        day: 'numeric'
      }).format(new Date())
      const currentDay = parseInt(istanbulDayStr)

      const prompt = `Sen bir Türk ${bot.profession || 'Muhasebe Uzmanı'}sın (İsmin ${bot.full_name}). Aşağıda bir meslektaşınla arandaki özel mesajlaşma geçmişi (arşiv) yer almaktadır.
Son gelen mesaja son derece doğal, sanki telefondan hızlıca yazıyormuş gibi samimi, insansı ve kısa bir cevap yazmanı istiyoruz.

Bugünün Tarihi: ${currentDateStr}

Mesajlaşma Geçmişi (Arşiv):
${historyStr}

Kurallar:
- KESİNLİKLE "abi", "kanka", "kardeşim", "bro", "kızım" gibi sokak ağzı/laubali/argo hitaplar KULLANMA. Finans/muhasebe dünyasının kendi içindeki samimi ama mesleki jargonuna uygun hitaplar tercih et (en popüleri ve doğalı **"üstadım"** veya **"hocam"** kelimeleridir, ya da doğrudan hiçbir hitap kullanmadan yaz).
- Cümlelerinde KESİNLİKLE soru sorma ("naber", "nasılsın", "ne yaptınız" vb. soru kalıplarını asla kullanma), sadece durumu bildir ve ertele/kapat.
- KESİNLİKLE "birazdan dönerim", "sonra yazacağım", "akşama detaylı konuşalım" gibi geleceğe yönelik geri dönüş vaatleri/sözleri VERME. Gerçek kullanıcıyı beklentiye sokmamak için sadece geç gördüğünü belirterek kibarca durumu açıkla, kolay gelsin dile ve konuyu kapat.
- Mesajları sanki iş yoğunluğu nedeniyle biraz gecikmeli görmüş gibi yaz (örn: "kusura bakmayın geç gördüm valla", "yoğunluktan mesajı yeni fark ettim kusura bakma", "mesaj geç düştü sanırım" gibi ifadeler kullanabilirsin).
- Mazeret Kuralı (Tarihe göre gerçekçi mazeret uydur):
  * Türkiye'de mali müşavirler/muhasebeciler için her ayın 15'i ile 26'sı arası yoğun beyanname ve bildirge dönemidir. Bugünün gününe bak (${currentDay}): Eğer gün değeri 15 ile 26 arasındaysa "beyanname dönemi yoğunluğu, SGK bildirge hazırlıkları" mazeretini kullanabilirsin.
  * Eğer gün değeri 1 ile 14 arasında VEYA 27 ile 31 arasındaysa beyanname yoğunluğu mazeretini KESİNLİKLE KULLANMA (gerçekçi olmaz). Bunun yerine şu gerçekçi mazeretleri kullan: "mükellef denetimi/ziyareti", "vergi dairesi/ticaret odasında evrak koşturmacası", "defter incelemesi/tetkiki var bu ara", "yeni mükellef açılış işlemleri", "yıl sonu/ay sonu fatura ve kapanış hazırlıkları", "genel ofis koşturmacası" vb.
- Sanki WhatsApp'tan aceleyle yazıyormuş gibi davran: Cümle başlarında küçük harf kullanabilirsin, noktalama işaretlerini (nokta, virgül) es geçebilirsin ya da gelişi güzel kullanabilirsin.
- Mesaj Tipi ve Yanıt Stratejisi (Çok Önemli):
  * **Senaryo A (Basit Sohbet / Selamlaşma / Hal Hatır / Tanışma):** Gelen son mesaj teknik olmayan basit bir selamlaşma ("selam", "mrb", "naber", "nasılsın") veya havadan sudan muhabbet ise, sohbeti uzatmamak için geç gördüğünü belirten çok kısa, kaçamak ve yoğunluğunu mazeret gösterip konuyu kibarca kapatan cevaplar yaz (örn: "selamlar hocam yoğunluktan yeni gördüm kusura bakma, kolay gelsin 👍").
  * **Senaryo B (Mesleki / Teknik / Mevzuat / Vergi Sorusu):** Eğer meslektaş size ciddi bir vergi kodu, SGK bildirgesi, KDV oranı, fatura, beyanname kalemi veya mali mevzuat sorusu soruyorsa KAÇAMAK CEVAP VERME. Soruyu 1-2 cümleyle son derece bilgili, profesyonel ve doğru bir şekilde kısaca yanıtla. Yanıtın sonuna mazeretine uygun kısa bir yoğunluk ifadesi ekleyip konuyu kapatabilirsin (örn: "selamlar hocam, KDV tevkifat oranı bu teslimde ... olarak uygulanmalıdır. bu aralar defter incelemesi yoğunluğu var pek buralara bakamıyorum ama umarım açıklayıcı olmuştur, kolay gelsin 👍").
- Konuşmayı çok uzatmamak için nazikçe erteleyen, kısa ve kaçamak cevaplar ver (Yalnızca Senaryo A için geçerlidir).
- Eğer gelen son mesajda veya yukarıdaki mesajlaşma geçmişinde (arşivinde) evlilik, ilişki durumu, yaş, özel hayat, flörtleşme, flört amaçlı tanışma teklifleri, çalıştığı firmanın/ofisin adı, tam adresi, nerede çalıştığı, hangi şehirde olduğu vb. detaylı kişisel veya kurumsal kimlik bilgileri sorgulanıyorsa KESİNLİKLE CEVAP VERME. Sadece ve sadece "[SKIP]" yaz (köşeli parantezleriyle birlikte). Başka hiçbir kelime veya karakter ekleme.
- Doğal Türkçe konuşma kelimelerini ve internet kısaltmalarını kullanabilirsin: "valla", "bu ara", "mrb", "selamlar", "yoğunum feci", "kusura bakmayın", "inşallah".
- Arada bir basit emojiler kullanabilirsin (örn: :) veya 👍 veya kolay gelsin).
- Sadece doğrudan yazacağın mesaj metnini döndür, başka hiçbir açıklama yapma veya JSON kullanma.`

      const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "gpt-5.4-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.85,
        })
      })

      const data = await openaiResponse.json()
      const replyContent = data.choices[0].message.content.trim()

      // Her halükarda gelen bu mesajı okundu (is_read: true) olarak işaretle ki sonsuz döngüye girmesin
      await supabase
        .from('messages')
        .update({ is_read: true })
        .eq('id', msg.id)

      if (replyContent.includes("[SKIP]")) {
        console.log(`Kişisel/flört/kurumsal içerikli mesaj algılandı, cevap verilmedi. Gelen: ${msg.body}`)
        continue
      }

      await supabase
        .from('messages')
        .insert({
          sender_id: bot.id,
          receiver_id: msg.sender_id,
          body: replyContent,
          // varsa conversation_id vs eklenebilir. Proje şemasına bağlıdır.
        })
        
      console.log(`Bota gelen mesaja cevap verildi. Bot: ${bot.id}, Gelen: ${msg.body}, Cevap: ${replyContent}`)
    }

    return new Response(JSON.stringify({ success: true, count: targets.length }), { status: 200 })
  } catch (error) {
    console.error('Simülasyon hatası:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
