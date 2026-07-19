import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const CITIES = [
  "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Aksaray", "Amasya", "Antalya", "Ardahan", 
  "Artvin", "Aydın", "Balıkesir", "Bartın", "Batman", "Bayburt", "Bilecik", "Bingöl", "Bitlis", 
  "Bolu", "Burdur", "Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli", "Diyarbakır", "Düzce", 
  "Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir", "Gaziantep", "Giresun", "Gümüşhane", 
  "Hakkari", "Hatay", "Iğdır", "Isparta", "İzmir", "Kahramanmaraş", "Karabük", "Karaman", "Kars", 
  "Kastamonu", "Kayseri", "Kırıkkale", "Kırklareli", "Kırşehir", "Kilis", "Kocaeli", "Konya", 
  "Kütahya", "Malatya", "Manisa", "Mardin", "Mersin", "Muğla", "Muş", "Nevşehir", "Niğde", 
  "Ordu", "Osmaniye", "Rize", "Sakarya", "Samsun", "Siirt", "Sinop", "Sivas", "Şanlıurfa", 
  "Şırnak", "Tekirdağ", "Tokat", "Trabzon", "Tunceli", "Uşak", "Van", "Yalova", "Yozgat", "Zonguldak"
];

const emailRegex = /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z]{2,})/gi;

async function fetchPlaceDetails(placeId: string) {
  const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=website,formatted_phone_number,formatted_address&key=${GOOGLE_PLACES_API_KEY}`;
  const response = await fetch(url);
  const data = await response.json();
  return data.result;
}

async function scrapeEmailFromWebsite(url: string): Promise<string[]> {
  console.log(`[Scraping] Attempting to scrape website: ${url}`);
  
  const fetchEmails = async (targetUrl: string): Promise<string[]> => {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout per page
      const response = await fetch(targetUrl, { 
        signal: controller.signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        }
      });
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        console.log(`[Scraping] Failed to fetch ${targetUrl}. Status: ${response.status}`);
        return [];
      }
      const html = await response.text();
      const matchedEmails = html.match(emailRegex);
      return matchedEmails || [];
    } catch (e) {
      console.error(`[Scraping] Error scraping ${targetUrl}:`, e);
      return [];
    }
  };

  let emails = await fetchEmails(url);

  // If no emails found on main page, try common contact pages
  if (emails.length === 0) {
    const baseUrl = url.replace(/\/$/, "");
    const contactPages = ["/iletisim", "/ileti%C5%9Fim", "/contact", "/bize-ulasin"];
    
    for (const page of contactPages) {
      console.log(`[Scraping] No emails on main page, trying ${baseUrl}${page}`);
      emails = await fetchEmails(`${baseUrl}${page}`);
      if (emails.length > 0) {
        break; // Stop trying if we found emails
      }
    }
  }

  try {
    if (emails && emails.length > 0) {
      // 1. Temel filtreleme (görsel uzantıları ve bilinen çöp/hata takip maillerini çıkar)
      let validEmails = emails
        .map(e => e.toLowerCase())
        .filter(e => !e.endsWith('.png') && !e.endsWith('.jpg') && !e.endsWith('.webp') && !e.includes('sentry') && !e.includes('wweeiihh') && !e.includes('example.com'));
      
      // Tekrarları temizle
      validEmails = [...new Set(validEmails)];

      if (validEmails.length > 0) {
        console.log(`[Scraping] Found emails for ${url}:`, validEmails);
        
        // Site URL'sinden alan adını çıkar (örn: aynurakdogan.com)
        const domainMatch = url.match(/:\/\/(www\.)?([^\/]+)/);
        const siteDomain = domainMatch ? domainMatch[2].toLowerCase() : "";
        
        // 2. Kurumsal ön ekler içerenler
        const professionalPrefixes = ['info@', 'iletisim@', 'smmm@', 'muhasebe@', 'contact@', 'destek@', 'hello@'];
        
        // Sadece domain maili veya kurumsal mail olanları filtrele
        const highQualityEmails = validEmails.filter(e => 
          (siteDomain && e.includes(siteDomain)) || 
          professionalPrefixes.some(prefix => e.startsWith(prefix))
        );

        // Eğer kaliteli mail bulduysa onları dön, bulamadıysa bulduklarının ilk 5 tanesini dön.
        if (highQualityEmails.length > 0) {
            return highQualityEmails.slice(0, 10); // Maksimum 10 mail
        } else {
            return validEmails.slice(0, 5); // Maksimum 5 mail
        }
      } else {
        console.log(`[Scraping] No valid emails left after filtering for ${url}`);
      }
    } else {
      console.log(`[Scraping] No emails found for ${url}`);
    }

    // Fallback: Generate info@domain.com if it's a custom domain
    const domainMatch = url.match(/:\/\/(www\.)?([^\/]+)/);
    const siteDomain = domainMatch ? domainMatch[2].toLowerCase() : "";
    
    const excludedDomains = ['google.com', 'blogspot.com', 'wordpress.com', 'wixsite.com', 'wix.com', 'instagram.com', 'facebook.com', 'twitter.com', 'linkedin.com', 'linktr.ee', 'weebly.com'];
    
    if (siteDomain && !excludedDomains.some(d => siteDomain.includes(d))) {
      console.log(`[Scraping] Assuming info@${siteDomain} as a fallback.`);
      return [`info@${siteDomain}`];
    }

  } catch (e) {
    console.error(`[Scraping] Error during filtering for ${url}:`, e);
  }
  return [];
}

serve(async (req) => {
  try {
    // Pick a random city or iterate through them
    const city = CITIES[Math.floor(Math.random() * CITIES.length)];
    const query = encodeURIComponent(`mali müşavir ${city}`);
    
    const placesUrl = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${query}&key=${GOOGLE_PLACES_API_KEY}`;
    const placesResponse = await fetch(placesUrl);
    const placesData = await placesResponse.json();

    console.log(`[Places API] Query: ${query}`);
    console.log(`[Places API] Status: ${placesData.status}`);
    console.log(`[Places API] Results count: ${placesData.results ? placesData.results.length : 0}`);

    if (!placesData.results) {
      console.error("[Places API] No results found or API error:", placesData);
      return new Response(JSON.stringify({ error: "No results found" }), { status: 400 });
    }

    const leads = [];

    for (const place of placesData.results.slice(0, 5)) { // Limit to 5 per run for edge function timeout limits
      const placeId = place.place_id;
      const name = place.name;
      
      // Check if place is a Chamber (Oda) and skip it
      const isChamber = name.toLowerCase().includes("odası") || 
                        name.toLowerCase().includes("smmmo") || 
                        name.toLowerCase().includes("ymmo");
      
      if (isChamber) {
        console.log(`[Main Loop] Skipping ${name} as it appears to be a Chamber of Commerce/Advisors.`);
        continue;
      }

      // Check if place_id already exists to avoid unnecessary scraping
      const { data: existing } = await supabase
        .from("marketing_leads")
        .select("id")
        .eq("place_id", placeId)
        .single();
        
      if (existing) {
        console.log(`[Main Loop] Skipping ${name} (${placeId}) as it already exists in DB.`);
        continue; // Skip if already have it
      }

      console.log(`[Main Loop] Fetching details for ${name} (${placeId})...`);
      const details = await fetchPlaceDetails(placeId);
      
      if (!details || !details.website) {
        console.log(`[Main Loop] No website found for ${name}. Skipping.`);
        continue; // We need a website to find an email
      }
      
      // Extra check for chamber in website URL
      if (details.website.toLowerCase().includes("smmmo") || details.website.toLowerCase().includes("ymmo")) {
          console.log(`[Main Loop] Skipping ${name} due to website URL indicating a Chamber: ${details.website}`);
          continue;
      }

      console.log(`[Main Loop] Calling scrape for ${name}, website: ${details.website}`);
      const scrapedEmails = await scrapeEmailFromWebsite(details.website);
      
      if (scrapedEmails && scrapedEmails.length > 0) {
        for (const email of scrapedEmails) {
          const lead = {
            place_id: placeId,
            name: name,
            email: email,
            phone: details.formatted_phone_number || null,
            website: details.website,
            city: city,
            address: details.formatted_address || null,
            is_emailed: false
          };
          leads.push(lead);
        }
      }
    }

    if (leads.length > 0) {
       // Insert into Supabase (Upsert based on email to prevent sending same mail twice)
       await supabase.from("marketing_leads").upsert(leads, { onConflict: "email", ignoreDuplicates: true });
    }

    return new Response(JSON.stringify({ 
      success: true, 
      city_scanned: city, 
      leads_found: leads.length,
      leads: leads
    }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Scraping error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
