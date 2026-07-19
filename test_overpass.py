import requests
import json

def test_overpass_api():
    print("OpenStreetMap Overpass API Testi Başlıyor...")
    
    # Overpass API endpoint
    url = "http://overpass-api.de/api/interpreter"
    
    # İstanbul için örnek bir sorgu oluşturuyoruz.
    # Tüm Türkiye'yi çekmek uzun sürebilir, test için İstanbul'u seçtik.
    # office=accountant veya office=tax_advisor olan yerleri arıyoruz.
    query = """
    [out:json][timeout:50];
    area["name"="İstanbul"]->.searchArea;
    (
      node["office"="accountant"](area.searchArea);
      way["office"="accountant"](area.searchArea);
      relation["office"="accountant"](area.searchArea);
      
      node["office"="tax_advisor"](area.searchArea);
      way["office"="tax_advisor"](area.searchArea);
      relation["office"="tax_advisor"](area.searchArea);
    );
    out tags;
    """
    
    print("Sorgu API'ye gönderiliyor (Bu işlem birkaç saniye sürebilir)...")
    response = requests.post(url, data={'data': query})
    
    if response.status_code == 200:
        data = response.json()
        elements = data.get('elements', [])
        
        print(f"\nToplam {len(elements)} adet mali müşavir / muhasebeci kaydı bulundu (İstanbul).")
        
        # Web sitesi olan kayıtları filtreleyelim
        with_website = [e for e in elements if 'tags' in e and 'website' in e['tags']]
        
        print(f"Bunlardan {len(with_website)} tanesinin web sitesi sisteme kayıtlı.\n")
        print("Web sitesi olan ilk 5 kaydın detayları:")
        print("-" * 50)
        
        for i, el in enumerate(with_website[:5]):
            tags = el.get('tags', {})
            name = tags.get('name', 'İsimsiz İşletme')
            website = tags.get('website', 'Yok')
            phone = tags.get('phone', tags.get('contact:phone', 'Yok'))
            
            print(f"{i+1}. İşletme Adı: {name}")
            print(f"   Web Sitesi: {website}")
            print(f"   Telefon: {phone}")
            print("-" * 50)
            
    else:
        print(f"Hata oluştu! Durum Kodu: {response.status_code}")
        print(response.text)

if __name__ == "__main__":
    test_overpass_api()
