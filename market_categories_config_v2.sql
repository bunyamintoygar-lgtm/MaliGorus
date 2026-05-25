-- Supabase SQL Editor'de çalıştırın
-- Market kategorilerini zengin JSON formatında (alt kategoriler, ikonlar, renkler) app_config tablosuna ekler

INSERT INTO public.app_config (key, value)
VALUES (
  'market_categories',
  '[
    {
      "id": "sablonlar",
      "label": "Şablonlar",
      "icon": "folder_open",
      "color": "4F46E5",
      "subcategories": [
        {"id": "is_yonetim", "label": "İş & Yönetim", "icon": "business"},
        {"id": "finans_muhasebe", "label": "Finans & Muhasebe", "icon": "calculate"},
        {"id": "vergi_hukuku", "label": "Vergi Hukuku", "icon": "gavel"},
        {"id": "pazarlama", "label": "Pazarlama", "icon": "trending_up"}
      ]
    },
    {
      "id": "dokumanlar",
      "label": "Dokümanlar",
      "icon": "description",
      "color": "0EA5E9",
      "subcategories": [
        {"id": "resmi_yazilar", "label": "Resmi Yazışmalar", "icon": "article"},
        {"id": "sozlesmeler", "label": "Sözleşmeler", "icon": "handshake"},
        {"id": "yonetmelikler", "label": "Yönetmelikler", "icon": "balance"},
        {"id": "kilavuzlar", "label": "Kılavuzlar", "icon": "menu_book"}
      ]
    },
    {
      "id": "paketler",
      "label": "Paketler",
      "icon": "inventory_2",
      "color": "10B981",
      "subcategories": [
        {"id": "baslangic", "label": "Başlangıç Paketleri", "icon": "workspace_premium"},
        {"id": "sektorler", "label": "Sektörel Paketler", "icon": "business"},
        {"id": "denetim", "label": "Denetim Paketleri", "icon": "verified"}
      ]
    },
    {
      "id": "araclar",
      "label": "Araçlar",
      "icon": "construction",
      "color": "F59E0B",
      "subcategories": [
        {"id": "hesaplayicilar", "label": "Hesaplayıcılar", "icon": "calculate"},
        {"id": "tablolar", "label": "Tablolar & Grafikler", "icon": "table_chart"},
        {"id": "yazilimlar", "label": "Pratik Yazılımlar", "icon": "computer"}
      ]
    },
    {
      "id": "egitimler",
      "label": "Eğitimler",
      "icon": "school",
      "color": "EC4899",
      "subcategories": [
        {"id": "video_egitim", "label": "Video Eğitimler", "icon": "computer"},
        {"id": "makaleler", "label": "Akademik Makaleler", "icon": "article"},
        {"id": "sunumlar", "label": "Seminer Sunumları", "icon": "assessment"}
      ]
    },
    {
      "id": "diger",
      "label": "Diğer",
      "icon": "more_horiz",
      "color": "64748B",
      "subcategories": [
        {"id": "diger_alt", "label": "Diğer Dosyalar", "icon": "label"}
      ]
    }
  ]'::jsonb
)
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value,
      updated_at = now();
