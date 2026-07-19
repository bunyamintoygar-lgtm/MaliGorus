const emailRegex = /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,})/gi;
const phoneRegex = /(?:0\s?)?(?:[1-9][0-9]{2})\s?[0-9]{3}\s?[0-9]{2}\s?[0-9]{2}/g;

async function scrapeChamberDirectory(targetUrl) {
    console.log(`[+] SMMM Odası Rehberi Taranıyor: ${targetUrl}`);
    console.log(`[!] Not: Birçok oda web sitesi KVKK sebebiyle rehberleri yoruma/aramaya kapatmış veya Captcha eklemiş olabilir.\n`);

    try {
        // Hedef sayfaya istek atıyoruz. Kendimizi normal bir tarayıcı gibi gösteriyoruz.
        const response = await fetch(targetUrl, {
            headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7"
            }
        });

        if (!response.ok) {
            throw new Error(`Sunucu ${response.status} hatası döndürdü.`);
        }

        const html = await response.text();
        
        // E-postaları ve telefonları Regex ile HTML'in içinden kazıyoruz
        const rawEmails = html.match(emailRegex) || [];
        const rawPhones = html.match(phoneRegex) || [];

        // E-postaları temizle (Gereksiz resim uzantıları veya çöp veriler)
        let cleanEmails = rawEmails
            .map(e => e.toLowerCase())
            .filter(e => !e.endsWith('.png') && !e.endsWith('.jpg') && !e.includes('sentry'));
        
        // Benzersiz (unique) olanları al
        cleanEmails = [...new Set(cleanEmails)];
        const cleanPhones = [...new Set(rawPhones)];

        console.log("=".repeat(50));
        console.log(`📌 TARAMA SONUCU (${targetUrl})`);
        console.log("=".repeat(50));
        
        console.log(`\nBulunan E-posta Adresleri (${cleanEmails.length} adet):`);
        if (cleanEmails.length > 0) {
            cleanEmails.forEach((email, i) => console.log(`  ${i+1}. ${email}`));
        } else {
            console.log("  [-] Bu sayfada açık e-posta adresi bulunamadı (Gizlenmiş veya listelenmemiş olabilir).");
        }

        console.log(`\nBulunan Telefon Numaraları (${cleanPhones.length} adet):`);
        if (cleanPhones.length > 0) {
            cleanPhones.slice(0, 10).forEach((phone, i) => console.log(`  ${i+1}. ${phone.trim()}`));
            if (cleanPhones.length > 10) console.log(`  ... ve ${cleanPhones.length - 10} numara daha.`);
        } else {
            console.log("  [-] Bu sayfada telefon numarası bulunamadı.");
        }

    } catch (error) {
        console.error(`\n[X] Sayfa çekilirken hata oluştu: ${error.message}`);
        console.log("Oda web sitesi erişimi engellemiş veya adres yanlış olabilir.");
    }
}

// Test için birkaç farklı odanın potansiyel rehber veya iletişim sayfalarını deneyelim
async function runTest() {
    // Bursa SMMM Odası ve Kocaeli SMMM Odası örnekleri
    const testUrls = [
        "https://www.bsmmmo.org.tr/", // Bursa
        "https://ksmmmo.org.tr/Iletisim" // Kocaeli
    ];

    for (const url of testUrls) {
        await scrapeChamberDirectory(url);
        console.log("\n" + "*".repeat(50) + "\n");
    }
}

runTest();
