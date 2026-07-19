import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

serve(async (req) => {
  try {
    // 1. Rastgele bir bot kullanıcı seç
    const { data: bots, error: botsError } = await supabase
      .from('profiles')
      .select('id, profession')
      .like('referral_code', 'YZ-%')

    if (botsError || !bots || bots.length === 0) {
      throw new Error('Bot kullanıcı bulunamadı.')
    }

    const randomBot = bots[Math.floor(Math.random() * bots.length)]

    const results: any[] = []

    // --- 1. CEVAP YAZMA AKIŞI (REPLY) ---
    try {
      // Rastgele aktif bir tartışma seç (Son 7 gün içinde açılmış)
      const { data: discussions, error: discError } = await supabase
        .from('discussions')
        .select('id, title, body, author_id')
        .eq('status', 'active')
        .order('created_at', { ascending: false })
        .limit(20)

      if (discError || !discussions || discussions.length === 0) {
        console.log('Cevaplanacak tartışma bulunamadı veya hata oluştu.')
      } else {
        // Botun daha önce cevap yazdığı tartışma ID'lerini çek
        const { data: alreadyReplied } = await supabase
          .from('discussion_replies')
          .select('discussion_id')
          .eq('author_id', randomBot.id)

        const excludedDiscussionIds = (alreadyReplied || []).map((r: any) => r.discussion_id)

        // Botun kendi açmadığı ve daha önce cevap vermediği bir tartışmayı seçmeye çalış
        let targetDiscussion = discussions.find(d => 
          d.author_id !== randomBot.id && 
          !excludedDiscussionIds.includes(d.id)
        )

        if (!targetDiscussion) {
          // Eğer uygun tartışma bulamazsa, sadece daha önce cevaplamadığı tartışmayı seç
          targetDiscussion = discussions.find(d => !excludedDiscussionIds.includes(d.id))
        }

        if (targetDiscussion) {
          // Tartışmaya yazılmış mevcut cevapları çek (Son 5 cevap)
          const { data: existingReplies } = await supabase
            .from('discussion_replies')
            .select('body, profiles(full_name, profession)')
            .eq('discussion_id', targetDiscussion.id)
            .order('created_at', { ascending: true })
            .limit(5)

          let existingRepliesStr = "Henüz hiç cevap yazılmamış."
          if (existingReplies && existingReplies.length > 0) {
            existingRepliesStr = existingReplies.map((r: any) => {
              const authorInfo = r.profiles ? `${r.profiles.full_name} (${r.profiles.profession})` : "Bir Meslektaş"
              return `${authorInfo}: ${r.body}`
            }).join("\n---\n")
          }

          // Deneyim Seviyesi Belirleme (Çeşitlilik İçin)
          const expRandom = Math.random()
          let experienceLevel = '10-15 yıllık kıdemli, çok tecrübeli ve profesyonel bir'
          if (expRandom < 0.2) {
            experienceLevel = 'mesleğe henüz 1-2 yıl önce başlamış, tecrübesiz ama öğrenmeye hevesli genç bir'
          } else if (expRandom < 0.5) {
            experienceLevel = '4-5 yıllık orta düzey deneyimli bir'
          }

          // Rastgele paragraf sayısı ve uzunluk belirleme (Tek düze yapay zeka şablonunu kırmak için)
          const lengthRandom = Math.random()
          let paragraphConstraint = ''
          if (lengthRandom < 0.3) {
            paragraphConstraint = 'sadece 1 ya da en fazla 2 kısa cümleden oluşan, son derece pratik, doğrudan ve net bir görüş veya kişisel tecrübe olsun (örn: "Biz geçen yıl benzer bir durumda interaktif yerine elden dilekçe vererek çözmüştük, sistem bazen hata veriyor").'
          } else if (lengthRandom < 0.7) {
            paragraphConstraint = 'sadece tek (1) kısa/orta paragraftan oluşsun. Hızlıca, doğrudan konuya odaklı bir görüş veya pratik bir çözüm belirt.'
          } else {
            paragraphConstraint = '1 ya da en fazla 2 paragraftan oluşsun, konuyu hafifçe detaylandıran orta uzunlukta bir cevap olsun.'
          }

          const prompt = `Sen ${experienceLevel} Türk ${randomBot.profession || 'Muhasebe Uzmanı'}sın. Aşağıda başka bir meslektaşının açtığı bir tartışma veya danışma konusu var. Ayrıca bu konuya şimdiye kadar yazılmış diğer cevaplar/yorumlar da aşağıda listelenmiştir.
Bunları dikkatlice oku, gerekirse diğer meslektaşlarının fikirlerine atıfta bulun, onlara katıl/katılma veya kendi çözümünü sunarak doğal, samimi, destekleyici veya ufuk açıcı bir cevap yaz.

Kurallar:
- Sadece cevabın kendisini döndür. JSON kullanma.
- Faydasız, içi boş ve tek kelimelik (örn: "Teşekkürler", "Katılıyorum", "Aynen") cevaplardan kaçın. Aşırı uzun veya sıkıcı da olmasın. Cevap ${paragraphConstraint}
- KESİNLİKLE YAPAY ZEKA (AI, ChatGPT, robotik süreç otomasyonu vb.) tavsiyeleri verme, yapay zekadan bahsetme. Klasik ve pratik vergi, SGK, beyanname ve mevzuat çözümlerine odaklan.
- İnsan gibi davran, bazen ufak yazım yanlışları yapabilirsin (çok abartmadan).
- Çok resmi bir dil kullanma, forum/sosyal medya samimiyetinde olsun.
- Sohbeti çok uzatacak açık uçlu sorular sorma.
- KESİNLİKLE "kesinlikle katılıyorum", "çok doğru bir tespit", "harika bir noktaya değinmişsiniz", "kesinlikle haklısınız" gibi klişe, yapay zeka kokan abartılı onaylama ve giriş ifadeleri KULLANMA. Doğrudan konuya gir veya daha doğal, profesyonel/samimi bir dille görüşünü belirt.

Tartışma Başlığı: "${targetDiscussion.title}"
Konu İçeriği: "${targetDiscussion.body}"

Şimdiye Kadar Yazılan Diğer Cevaplar/Yorumlar:
${existingRepliesStr}`

          const openaiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${OPENAI_API_KEY}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify({
              model: "gpt-5.6-luna",
              messages: [{ role: "user", content: prompt }],
              temperature: 0.8,
            })
          })

          const data = await openaiResponse.json()
          const replyContent = data.choices[0].message.content.trim()

          const { error: insertError } = await supabase
            .from('discussion_replies')
            .insert({
              discussion_id: targetDiscussion.id,
              author_id: randomBot.id,
              body: replyContent
            })

          if (insertError) throw insertError

          // Ayrıca konunun izlenme sayısını artıralım (Ziyaret edildiği için)
          await supabase.rpc('increment_discussion_view_count', { p_discussion_id: targetDiscussion.id })

          console.log(`Cevap eklendi: Discussion ${targetDiscussion.id}`)
          results.push({ action: 'reply', success: true, discussion_id: targetDiscussion.id })
        }
      }
    } catch (e) {
      console.error('Cevap yazma simülasyonu hatası:', e)
      results.push({ action: 'reply', success: false, error: e.message })
    }

    // --- 2. BEĞENİ AKIŞI (LIKE) ---
    try {
      // Sadece verilen cevapları beğen
      const { data: replies } = await supabase
        .from('discussion_replies')
        .select('id, discussion_id')
        .order('created_at', { ascending: false })
        .limit(30)

      if (replies && replies.length > 0) {
        const target = replies[Math.floor(Math.random() * replies.length)]
        const { error: likeError } = await supabase
          .from('reply_likes')
          .upsert({ reply_id: target.id, user_id: randomBot.id })

        if (likeError) throw likeError
        
        // Cevap beğenildiğinde, bağlı olduğu ana tartışmanın izlenme sayısını da artıralım (Ziyaret edildiği için)
        if (target.discussion_id) {
          await supabase.rpc('increment_discussion_view_count', { p_discussion_id: target.discussion_id })
        }

        console.log(`Cevap beğenildi: ${target.id}`)
        results.push({ action: 'like', success: true, reply_id: target.id })
      }
    } catch (e) {
      console.error('Beğeni simülasyonu hatası:', e)
      results.push({ action: 'like', success: false, error: e.message })
    }

    // --- 3. ANKET OYLAMA AKIŞI (VOTE) ---
    // %30 ihtimalle aktif anket varsa ona da oy versin
    if (Math.random() < 0.3) {
      try {
        const { data: activeSurveys, error: surveyError } = await supabase
          .from('surveys')
          .select('id, title, options')
          .eq('status', 'active')
          .gt('expires_at', new Date().toISOString())
          .limit(10)

        if (!surveyError && activeSurveys && activeSurveys.length > 0) {
          const targetSurvey = activeSurveys[Math.floor(Math.random() * activeSurveys.length)]
          
          if (targetSurvey.options && targetSurvey.options.length > 0) {
            const targetOption = targetSurvey.options[Math.floor(Math.random() * targetSurvey.options.length)]

            const { error: insertVoteError } = await supabase
              .from('survey_votes')
              .insert({
                survey_id: targetSurvey.id,
                user_id: randomBot.id,
                option_id: targetOption.id
              })

            if (!insertVoteError) {
              const newOptions = (targetSurvey.options || []).map((opt: any) => {
                if (opt.id === targetOption.id) {
                  return { ...opt, votes: (opt.votes || 0) + 1 }
                }
                return opt
              })

              const { error: updateError } = await supabase
                .from('surveys')
                .update({ options: newOptions })
                .eq('id', targetSurvey.id)

              if (updateError) throw updateError
              console.log(`Bot ${randomBot.id} anket oyladı: ${targetSurvey.title} -> ${targetOption.text}`)
              results.push({ action: 'vote', success: true, survey_id: targetSurvey.id })
            }
          }
        }
      } catch (e) {
        console.error('Anket oylama simülasyonu hatası:', e)
        results.push({ action: 'vote', success: false, error: e.message })
      }
    }

    return new Response(JSON.stringify({ success: true, results }), { status: 200 })
  } catch (error) {
    console.error('Simülasyon hatası:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
