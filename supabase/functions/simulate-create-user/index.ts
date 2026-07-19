import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts"
import { decode as base64Decode } from "https://deno.land/std@0.168.0/encoding/base64.ts"
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY')!

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  }
})

// Deno ortamında crypto.randomUUID kullanılabilir
const generateRandomPassword = () => crypto.randomUUID().replace(/-/g, '') + 'A1!'

// Türkçe karakterleri İngilizce karakterlere çeviren ve e-posta üreten yardımcı fonksiyon
const convertToRealisticEmail = (fullName: string): string => {
  const turkishChars: { [key: string]: string } = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
    'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
    'â': 'a', 'î': 'i', 'û': 'u'
  }
  
  const cleanName = fullName
    .split('')
    .map(char => turkishChars[char] || char)
    .join('')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '') // Özel karakterleri temizle
    .trim()
    .replace(/\s+/g, '.') // Boşlukları nokta yap (örn: hakan.celik)
  
  // Rastgele popüler bir e-posta sağlayıcısı seç
  const providers = ['gmail.com', 'hotmail.com', 'outlook.com', 'yahoo.com']
  const randomProvider = providers[Math.floor(Math.random() * providers.length)]
  
  // Rastgele bir doğum yılı/şehir plakası vb ekle (örn: hakan.celik34, hakan.celik1989)
  const formats = [
    () => `${cleanName}`,
    () => `${cleanName}${Math.floor(Math.random() * 90 + 10)}`, // Plaka veya uğurlu sayı (örn: 34, 55, 61)
    () => `${cleanName}${Math.floor(Math.random() * 45 + 1965)}`, // Doğum yılı (örn: 1982, 1990)
    () => `${cleanName.replace('.', '_')}`, // Nokta yerine alt tire
    () => `${cleanName.replace('.', '_')}${Math.floor(Math.random() * 90 + 10)}`
  ]
  
  const emailUser = formats[Math.floor(Math.random() * formats.length)]()
  return `${emailUser}@${randomProvider}`
}

serve(async (req) => {
  try {
    // 1. Profil Mesleğini Belirle (Kullanıcının belirttiği yeni geniş liste üzerinden ağırlıklı seçim)
    const professionsList = [
      { id: 'smmm', label: 'SMMM', weight: 35 },
      { id: 'muhasebe_uzmani', label: 'Muhasebe Uzmanı', weight: 15 },
      { id: 'muhasebe_calisani', label: 'Muhasebe Çalışanı', weight: 10 },
      { id: 'stajyer', label: 'Stajyer', weight: 8 },
      { id: 'denetci', label: 'Denetçi', weight: 5 },
      { id: 'finans_calisani', label: 'Finans / Mali İşler Çalışanı', weight: 5 },
      { id: 'sirket_sahibi', label: 'Şirket Sahibi / Girişimci', weight: 4 },
      { id: 'cfo_finans_muduru', label: 'CFO / Finans Müdürü', weight: 3 },
      { id: 'avukat', label: 'Avukat', weight: 2 },
      { id: 'gelir_uzmani', label: 'Gelir Uzmanı / Vergi Denetmeni', weight: 2 },
      { id: 'sgk_uzmani', label: 'SGK Müfettişi / Uzmanı', weight: 2 },
      { id: 'ik_bordro_uzmani', label: 'İK / Bordro Uzmanı', weight: 2 },
      { id: 'gumruk_musaviri', label: 'Gümrük Müşaviri', weight: 1 },
      { id: 'banka_sigorta', label: 'Banka / Sigorta Çalışanı', weight: 1 },
      { id: 'akademisyen', label: 'Akademisyen', weight: 1 },
      { id: 'finans_ogrencisi', label: 'Muhasebe / Finans Öğrencisi', weight: 1 },
      { id: 'yatirim_danismani', label: 'Yatırım Danışmanı', weight: 1 },
      { id: 'leasing_factoring', label: 'Leasing / Factoring Uzmanı', weight: 1 },
      { id: 'transfer_fiyatlandirma', label: 'Transfer Fiyatlandırma Uzmanı', weight: 0.5 },
      { id: 'diger', label: 'Diğer', weight: 0.5 }
    ]

    const totalWeight = professionsList.reduce((acc, curr) => acc + curr.weight, 0)
    let randomWeight = Math.random() * totalWeight
    let chosenProf = professionsList[0]
    
    for (const prof of professionsList) {
      randomWeight -= prof.weight
      if (randomWeight <= 0) {
        chosenProf = prof
        break
      }
    }

    const assignedProfession = chosenProf.id
    const assignedProfessionLabel = chosenProf.label

    // Yaş ve Tarz Belirleme (Kod tarafında - Çeşitlilik kuralı)
    const gender = Math.random() < 0.45 ? 'Kadın' : 'Erkek'

    // Yaş Belirle
    const ageBrackets = [
      { type: 'genc', min: 23, max: 30, weight: 25 },
      { type: 'orta_yas', min: 31, max: 45, weight: 45 },
      { type: 'olgun', min: 46, max: 55, weight: 20 },
      { type: 'cok_olgun', min: 56, max: 68, weight: 10 }
    ]
    const totalAgeWeight = ageBrackets.reduce((acc, curr) => acc + curr.weight, 0)
    let randomAgeWeight = Math.random() * totalAgeWeight
    let chosenBracket = ageBrackets[1] // fallback orta yaş
    for (const bracket of ageBrackets) {
      randomAgeWeight -= bracket.weight
      if (randomAgeWeight <= 0) {
        chosenBracket = bracket
        break
      }
    }
    const chosenAge = Math.floor(Math.random() * (chosenBracket.max - chosenBracket.min + 1)) + chosenBracket.min

    // Yaş grubuna göre sıfatlar ekle
    let ageDescriptor = ""
    if (chosenBracket.type === 'genc') ageDescriptor = "genç ve dinamik görünümlü"
    else if (chosenBracket.type === 'orta_yas') ageDescriptor = "orta yaşlı, tecrübeli ve profesyonel"
    else if (chosenBracket.type === 'olgun') ageDescriptor = "olgun, kıdemli ve saygın görünümlü"
    else if (chosenBracket.type === 'cok_olgun') ageDescriptor = "çok olgun, beyaz/kır saçlı, tecrübeli ve bilge bakışlı"

    // Tarz/Stil Belirle
    let chosenStyle = ""
    if (gender === 'Kadın') {
      const styles = [
        { desc: 'zarif ve şık bir başörtüsü (türban) takmış, modern ve profesyonel giyimli', weight: 25 },
        { desc: 'sarışın veya açık kumral saçlı, modern saç kesimli, hafif makyajlı', weight: 15 },
        { desc: 'esmer, koyu kahverengi veya siyah saçlı, şık ve modern görünümlü', weight: 30 },
        { desc: 'kumral saçlı, doğal makyajsız, sade ve kurumsal görünümlü', weight: 20 },
        { desc: 'modern tarzda gözlükler takan, kısa saçlı, yaratıcı ve entelektüel görünümlü', weight: 10 }
      ]
      const totalS = styles.reduce((acc, curr) => acc + curr.weight, 0)
      let r = Math.random() * totalS
      for (const s of styles) {
        r -= s.weight
        if (r <= 0) {
          chosenStyle = s.desc
          break
        }
      }
    } else {
      const styles = [
        { desc: 'kirli sakallı veya hafif sakallı, kumral veya esmer saçlı, doğal', weight: 40 },
        { desc: 'sinekkaydı tıraşlı, kurumsal ve çok profesyonel takım elbiseli görünümlü', weight: 20 },
        { desc: 'sarışın veya açık renk saçlı, modern tıraşlı', weight: 10 },
        { desc: 'kır saçlı veya sakallı, olgun ve tecrübeli hatlara sahip', weight: 20 },
        { desc: 'entelektüel tarzda şık kemik gözlükleri olan, modern ve karizmatik saç kesimli', weight: 10 }
      ]
      const totalS = styles.reduce((acc, curr) => acc + curr.weight, 0)
      let r = Math.random() * totalS
      for (const s of styles) {
        r -= s.weight
        if (r <= 0) {
          chosenStyle = s.desc
          break
        }
      }
    }

    const assignedAppearance = `${ageDescriptor}, ${chosenStyle}`

    // 2. OpenAI ile Profil Üret (Sadece 1 kişi)
    const profilePrompt = `Bana 1 adet farklı Türk profili üret.
Kurallar:
- Şehir: Türkiye'den rastgele bir şehir.
- Meslek: Kesinlikle '${assignedProfessionLabel}' olsun.
- İsim: Gerçekçi ve çok çeşitli rastgele bir isim seçin. Hem ad hem de soyad tam olarak yazılsın (örn: 'Hakan Çelik', 'Zeynep Bulut', 'Burak Taşkın'). Asla hep aynı isimleri kullanma, her seferinde tamamen farklı ve yaratıcı ol.
- Cinsiyet: Kesinlikle '${gender}' olsun.
- Yaş: Kesinlikle ${chosenAge} olsun.
- Görünüm Açıklaması (appearance): Sadece ve kesinlikle şu ifadeden yola çıkarak Türkçe bir fiziksel tasvir oluştur: '${assignedAppearance}'.
Çıktı SADECE JSON formatında bir obje olsun. (Markdown kodu kullanma).
Örnek format: {"name": "Hakan Çelik", "age": ${chosenAge}, "gender": "${gender}", "city": "İstanbul", "appearance": "kır saçlı, esmer, hafif sakallı ve gözlüklü"}`

    const profileResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-5.6-luna", // Kullanıcının belirttiği yeni nesil model
        messages: [{ role: "user", content: profilePrompt }],
        temperature: 0.9, // Çeşitliliği artırmak için temperature yükseltildi
      })
    })

    const profileData = await profileResponse.json()
    let profileContent = profileData.choices[0].message.content.trim()
    if (profileContent.startsWith('```json')) {
      profileContent = profileContent.replace(/^```json\n/, '').replace(/\n```$/, '')
    } else if (profileContent.startsWith('```')) {
      profileContent = profileContent.replace(/^```\n/, '').replace(/\n```$/, '')
    }
    const profile = JSON.parse(profileContent)

    // 2. Profil Resmi Üret ("gpt-image-2" modeli ile)
    const imagePrompt = `Gerçekçi bir insan fotoğrafı. ${profile.age} yaşında, ${profile.gender === 'Kadın' ? 'Kadın' : 'Erkek'} Türk vatandaşı, mesleği '${assignedProfessionLabel}'. 
Fiziksel Özellikler: ${profile.appearance}. 
Stil: Vesikalık veya cep telefonu kamerasıyla çekilmiş doğal bir özçekim (selfie). Sosyal medya profili için. 
Önemli Not: Çok profesyonel, yapay, kusursuz veya manken gibi OLMAMALI. Tamamen sıradan, sokaktaki herhangi bir vatandaş gibi görünmeli. Asimetriler, hafif cilt kusurları veya doğal ışık yansımaları içerebilir.`
    
    console.log(`Fotoğraf oluşturuluyor: ${profile.name} - ${profile.age} - ${profile.city}`)
    const imageGenResponse = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-image-2", // Kullanıcının belirttiği model
        prompt: imagePrompt,
        n: 1,
        size: "1024x1024", // gpt-image-2 genellikle 1024x1024 destekler
        quality: "low"
      })
    })

    let avatarUrl = null
    const result = await imageGenResponse.json()

    if (!imageGenResponse.ok) {
      console.warn(`Resim üretilemedi (gpt-image-2 API çağrısı başarısız olabilir): ${result.error?.message || JSON.stringify(result)}`)
    } else {
      let imageBuffer: Uint8Array;
      const imageData = result.data?.[0];

      if (imageData?.b64_json) {
        imageBuffer = base64Decode(imageData.b64_json)
      } else if (imageData?.url) {
        const imageRes = await fetch(imageData.url)
        imageBuffer = new Uint8Array(await imageRes.arrayBuffer())
      } else {
        throw new Error("No image data found in OpenAI response")
      }

      // Resmi ImageScript ile işle (Boyutlandır & Sıkıştır)
      const img = await Image.decode(imageBuffer)
      img.resize(256, 256)
      const compressed = await img.encodeJPEG(80)

      const fileName = `profiles/${crypto.randomUUID()}.jpg`
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(fileName, compressed, {
          contentType: 'image/jpeg',
          upsert: true,
        })

      if (!uploadError) {
        const { data: { publicUrl } } = supabase.storage
          .from('avatars')
          .getPublicUrl(fileName)
        avatarUrl = publicUrl
        console.log(`Fotoğraf başarıyla işlendi ve yüklendi: ${avatarUrl}`)
      } else {
        console.error('Storage Upload Error:', uploadError)
      }
    }

    // 3. Kullanıcıyı oluştur (Auth)
    const email = convertToRealisticEmail(profile.name)
    const password = generateRandomPassword()

    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true,
      user_metadata: { 
        is_virtual: true,
        full_name: profile.name,
        avatar_url: avatarUrl
      } // Ek güvenlik için ve Trigger'ın otomatik alması için
    })

    if (authError) throw authError

    const userId = authData.user.id

    // Auth Trigger'ın public.profiles'ı oluşturmasını bekleyelim
    await new Promise(resolve => setTimeout(resolve, 2000))

    const botReferralCode = `YZ-${Math.floor(100000 + Math.random() * 900000)}`

    // 4. Profili Güncelle (trigger oluşturduğu için update kullanıyoruz)
    const { error: profileUpdateError } = await supabase
      .from('profiles')
      .update({
        full_name: profile.name,
        profession: assignedProfession,
        avatar_url: avatarUrl,
        referral_code: botReferralCode,
        profile_completed: true,
        is_verified: true,
      })
      .eq('id', userId)

    if (profileUpdateError) {
      console.warn('Update failed, trying upsert...', profileUpdateError)
      // Eğer trigger yoksa veya başarısız olduysa upsert deneyelim
      const { error: upsertError } = await supabase
        .from('profiles')
        .upsert({
          id: userId,
          full_name: profile.name,
          profession: assignedProfession,
          avatar_url: avatarUrl,
          referral_code: botReferralCode,
          profile_completed: true,
          is_verified: true,
        }, { onConflict: 'id' })
        
      if (upsertError) throw upsertError
    }

    console.log(`Yeni sanal kullanıcı başarıyla oluşturuldu: ${profile.name}`)

    return new Response(JSON.stringify({ 
      success: true, 
      user: { id: userId, name: profile.name, avatar: avatarUrl } 
    }), { status: 200 })

  } catch (error) {
    console.error('Kullanıcı oluşturma simülasyon hatası:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
