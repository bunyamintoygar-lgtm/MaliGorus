const query = `
[out:json][timeout:25];
(
  node["office"="accountant"](40.9, 28.9, 41.1, 29.1);
  way["office"="accountant"](40.9, 28.9, 41.1, 29.1);
  relation["office"="accountant"](40.9, 28.9, 41.1, 29.1);
  
  node["office"="tax_advisor"](40.9, 28.9, 41.1, 29.1);
  way["office"="tax_advisor"](40.9, 28.9, 41.1, 29.1);
  relation["office"="tax_advisor"](40.9, 28.9, 41.1, 29.1);
);
out body;
>;
out skel qt;
`;

async function testOverpassApi() {
    console.log("OpenStreetMap Overpass API Testi Başlıyor...");
    console.log("Alternatif API sunucusuna bağlanılıyor (Kumi Systems)...");

    try {
        const response = await fetch("https://overpass.kumi.systems/api/interpreter", {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "MaliGorus-Test/1.0",
                "Accept": "application/json"
            },
            body: `data=${encodeURIComponent(query)}`
        });

        if (!response.ok) {
            const errText = await response.text();
            throw new Error(`HTTP error! status: ${response.status}, message: ${errText}`);
        }

        const data = await response.json();
        const elements = data.elements || [];

        console.log(`\nToplam ${elements.length} adet harita objesi bulundu.`);

        // Sadece web sitesi olan muhasebeci/mali müşavirleri filtrele
        const withWebsite = elements.filter(el => 
            el.tags && 
            (el.tags.office === "accountant" || el.tags.office === "tax_advisor") && 
            el.tags.website
        );
        
        console.log(`Bunlardan ${withWebsite.length} tanesinin web sitesi sisteme kayıtlı.\n`);
        
        if(withWebsite.length > 0) {
            console.log("Web sitesi olan ilk 5 kaydın detayları:");
            console.log("-".repeat(50));

            withWebsite.slice(0, 5).forEach((el, index) => {
                const tags = el.tags || {};
                const name = tags.name || "İsimsiz İşletme";
                const website = tags.website || "Yok";
                const phone = tags.phone || tags["contact:phone"] || "Yok";

                console.log(`${index + 1}. İşletme Adı: ${name}`);
                console.log(`   Web Sitesi: ${website}`);
                console.log(`   Telefon: ${phone}`);
                console.log("-".repeat(50));
            });
        } else {
            console.log("Bu küçük alanda web sitesi eklenmiş bir ofis bulunamadı. Aramayı tüm Türkiye'ye genişletebiliriz.");
        }

    } catch (error) {
        console.error("Hata oluştu:", error);
    }
}

testOverpassApi();
