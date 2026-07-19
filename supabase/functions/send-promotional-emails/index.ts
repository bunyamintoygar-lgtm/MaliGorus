import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// SMTP Settings
const SMTP_HOSTNAME = Deno.env.get("SMTP_HOSTNAME") ?? "smtp-legacy.office365.com";
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") ?? "587");
const SMTP_USERNAME = Deno.env.get("SMTP_USERNAME") ?? Deno.env.get("SMTP_USER") ?? "info@maligorus.com";
const SMTP_PASSWORD = Deno.env.get("SMTP_PASSWORD") ?? Deno.env.get("SMTP_PASS") ?? "";
const SENDER_EMAIL = Deno.env.get("SENDER_EMAIL") ?? "info@maligorus.com";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const EMAIL_SUBJECT = "MaliGörüş Ailesi Büyüyor! Mali Müşavirlere Özel Kapalı Ağa Katılın";
const EMAIL_TEMPLATE = `
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MaliGörüş'e Katılın</title>
</head>
<body style="height: 100% !important; margin: 0 !important; padding: 20px 0 !important; width: 100% !important; font-family: 'Segoe UI', Arial, sans-serif; background-color: #f4f6f9; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%;">

<table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse !important; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
    <tr>
        <td align="center" style="padding: 10px 0; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
            <!-- Ana Konteyner -->
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse !important; max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.05); mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                
                <!-- HEADER (Logo) -->
                <tr>
                    <td align="center" style="background-color: #ffffff; padding: 30px 20px; border-bottom: 1px solid #eeeeee; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <img src="https://maligorus.com/logo.png" alt="MaliGörüş" style="height: 70px; width: auto; border: 0; display: block; margin: 0 auto;">
                    </td>
                </tr>

                <!-- HERO SECTION -->
                <tr>
                    <td style="background-color: #ffffff; padding: 40px 30px 20px 30px; text-align: center; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <h2 style="color: #001a4d; margin: 0 0 10px 0; font-size: 26px; font-weight: 800; line-height: 1.2;">
                            HER GEÇEN GÜN<br>DAHA GÜÇLÜ BÜYÜYORUZ!
                        </h2>
                        <h3 style="color: #4a4a4a; margin: 0 0 20px 0; font-size: 20px; font-weight: 600;">
                            Siz de aramıza katılın.
                        </h3>
                        <p style="color: #4a4a4a; margin: 0; font-size: 16px; line-height: 1.6;">
                            Mali müşavirler için kurduğumuz kapalı network sistemimiz her geçen gün büyüyor. Mesleki bilgi ve tecrübelerimizi paylaşarak, <strong style="color: #003399;">birlikte daha güçlü</strong> bir camia oluşturuyoruz.
                        </p>
                    </td>
                </tr>

                <!-- NELER YAPIYORUZ BÖLÜMÜ -->
                <tr>
                    <td style="background-color: #f9f9f9; padding: 30px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <div style="text-align: center; margin-bottom: 25px;">
                            <span style="color: #003399; font-weight: bold; font-size: 14px; letter-spacing: 1px;">NELER YAPIYORUZ?</span>
                            <hr style="border: none; border-top: 1px solid #e0e0e0; width: 50px; margin: 10px auto;">
                        </div>

                        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse !important; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                            <!-- Madde 1 -->
                            <tr>
                                <td width="70" valign="top" style="padding-bottom: 20px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="background-color: white; width: 50px; height: 50px; border-radius: 8px; border: 1px solid #e0e0e0; text-align: center; line-height: 50px; font-size: 24px;">💬</div>
                                </td>
                                <td valign="top" style="padding-bottom: 20px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <h4 style="color: #003399; margin: 0 0 5px 0; font-size: 16px;">TARTIŞMALAR YAPIYORUZ</h4>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 14px; line-height: 1.5;">Güncel konularda tartışmalar açıyor, fikir alışverişinde bulunuyoruz.</p>
                                </td>
                            </tr>
                            <!-- Madde 2 -->
                            <tr>
                                <td width="70" valign="top" style="padding-bottom: 20px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="background-color: white; width: 50px; height: 50px; border-radius: 8px; border: 1px solid #e0e0e0; text-align: center; line-height: 50px; font-size: 24px;">👥</div>
                                </td>
                                <td valign="top" style="padding-bottom: 20px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <h4 style="color: #003399; margin: 0 0 5px 0; font-size: 16px;">GÖRÜŞLER ALIYORUZ</h4>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 14px; line-height: 1.5;">Uzman meslektaşlarımızın tecrübelerinden faydalanarak doğru kararlar alıyoruz.</p>
                                </td>
                            </tr>
                            <!-- Madde 3 -->
                            <tr>
                                <td width="70" valign="top" style="padding-bottom: 20px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="background-color: white; width: 50px; height: 50px; border-radius: 8px; border: 1px solid #e0e0e0; text-align: center; line-height: 50px; font-size: 24px;">📊</div>
                                </td>
                                <td valign="top" style="padding-bottom: 20px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <h4 style="color: #003399; margin: 0 0 5px 0; font-size: 16px;">ANKETLER DÜZENLİYORUZ</h4>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 14px; line-height: 1.5;">Sektörel anketlerle görüşümüzü bildiriyor, geleceğe yön veriyoruz.</p>
                                </td>
                            </tr>
                            <!-- Madde 4 -->
                            <tr>
                                <td width="70" valign="top" style="mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="background-color: white; width: 50px; height: 50px; border-radius: 8px; border: 1px solid #e0e0e0; text-align: center; line-height: 50px; font-size: 24px;">💼</div>
                                </td>
                                <td valign="top" style="mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <h4 style="color: #003399; margin: 0 0 5px 0; font-size: 16px;">İLANLAR PAYLAŞIYORUZ</h4>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 14px; line-height: 1.5;">Ofis, eleman, iş ortaklığı gibi ilanlarla fırsatları kaçırmıyoruz.</p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- WHATSAPP FARKI BÖLÜMÜ -->
                <tr>
                    <td style="background-color: #ffffff; padding: 40px 30px 10px 30px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <div style="text-align: center; margin-bottom: 25px;">
                            <span style="color: #003399; font-weight: bold; font-size: 14px; letter-spacing: 1px;">WHATSAPP GRUPLARINDAN FARKIMIZ NE?</span>
                            <hr style="border: none; border-top: 1px solid #e0e0e0; width: 50px; margin: 10px auto;">
                        </div>

                        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse !important; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                            <!-- Tablo Başlığı -->
                            <tr>
                                <td width="50%" align="center" style="background-color: #f0f0f0; padding: 15px 10px; font-weight: bold; color: #4a4a4a; font-size: 13px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    WHATSAPP GRUPLARI
                                </td>
                                <td width="50%" align="center" style="background-color: #001a4d; padding: 15px 10px; font-weight: bold; color: #ffffff; font-size: 13px; border-bottom: 1px solid #001a4d; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    MALİGÖRÜŞ
                                </td>
                            </tr>
                            <!-- Satır 1 -->
                            <tr>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> Mesajlar hızla kaybolur, bulmak zordur.
                                </td>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> Konular kategorilere ayrılır ve her zaman bulunabilir.
                                </td>
                            </tr>
                            <!-- Satır 2 -->
                            <tr>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> Aynı sorular tekrar tekrar sorulur.
                                </td>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> Önceki tartışmalar arşivlenir, tekrar etmez.
                                </td>
                            </tr>
                            <!-- Satır 3 -->
                            <tr>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> Bilgiye ulaşmak zordur.
                                </td>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> Arama ile saniyeler içinde ilgili konuya ulaşılır.
                                </td>
                            </tr>
                            <!-- Satır 4 -->
                            <tr>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> Çok sayıda gereksiz bildirim gelir.
                                </td>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> Sadece ilgilendiğiniz konuları takip edersiniz.
                                </td>
                            </tr>
                            <!-- Satır 5 -->
                            <tr>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> Dosya ve bilgi düzeni yoktur.
                                </td>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> Tartışmalar, anketler ve ilanlar düzenli şekilde saklanır.
                                </td>
                            </tr>
                            <!-- Satır 6 -->
                            <tr>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> Kimin gerçekten uzman olduğu belli olmayabilir.
                                </td>
                                <td style="padding: 12px 10px; border-bottom: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> Uzman meslektaşlardan doğrudan görüş alırsınız.
                                </td>
                            </tr>
                            <!-- Satır 7 -->
                            <tr>
                                <td style="padding: 12px 10px; border-right: 1px solid #e0e0e0; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #888;">✖</span> İş ilanları sohbet içinde kaybolur.
                                </td>
                                <td style="padding: 12px 10px; font-size: 12px; color: #4a4a4a; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <span style="color: #003399; font-weight: bold;">✔</span> İlanlar ayrı bir bölümde yayınlanır.
                                </td>
                            </tr>
                        </table>
                        
                        <!-- Alt Bilgi Kutusu -->
                        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top: 20px; background-color: #f0f4fb; border-radius: 8px; border-collapse: collapse !important; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                            <tr>
                                <td width="60" valign="center" align="center" style="padding: 15px 0 15px 15px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="font-size: 32px; color: #001a4d;">🛡️</div>
                                </td>
                                <td valign="center" style="padding: 15px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <h4 style="color: #001a4d; margin: 0 0 5px 0; font-size: 14px;">MaliGörüş bir mesajlaşma grubu değildir.</h4>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 12px; line-height: 1.4;">
                                        Mali müşavirler için geliştirilmiş, bilgi paylaşımı, uzman görüşü, tartışmalar, anketler ve mesleki ilanları tek çatı altında toplayan profesyonel bir platformdur.
                                    </p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- NEDEN MALİGÖRÜŞ BÖLÜMÜ -->
                <tr>
                    <td style="background-color: #ffffff; padding: 40px 30px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <div style="text-align: center; margin-bottom: 25px;">
                            <span style="color: #003399; font-weight: bold; font-size: 14px; letter-spacing: 1px;">NEDEN MALİGÖRÜŞ?</span>
                            <hr style="border: none; border-top: 1px solid #e0e0e0; width: 50px; margin: 10px auto;">
                        </div>

                        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="text-align: center; border-collapse: collapse !important; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                            <tr>
                                <td width="25%" valign="top" style="padding: 0 5px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="color: #003399; font-size: 20px; margin-bottom: 10px;">✔️</div>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 12px; line-height: 1.4;">Sadece mali müşavirlere özel kapalı sistem</p>
                                </td>
                                <td width="25%" valign="top" style="padding: 0 5px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="color: #003399; font-size: 20px; margin-bottom: 10px;">✔️</div>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 12px; line-height: 1.4;">Güvenli, kurumsal ve profesyonel ortam</p>
                                </td>
                                <td width="25%" valign="top" style="padding: 0 5px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="color: #003399; font-size: 20px; margin-bottom: 10px;">✔️</div>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 12px; line-height: 1.4;">Bilgi paylaşımı ile mesleki gelişim</p>
                                </td>
                                <td width="25%" valign="top" style="padding: 0 5px; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <div style="color: #003399; font-size: 20px; margin-bottom: 10px;">✔️</div>
                                    <p style="color: #4a4a4a; margin: 0; font-size: 12px; line-height: 1.4;">Genişleyen güçlü bir network ağı</p>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- CTA BÖLÜMÜ -->
                <tr>
                    <td style="background-color: #f9f9f9; padding: 40px 30px; text-align: center; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <p style="color: #4a4a4a; margin: 0 0 25px 0; font-size: 16px; line-height: 1.6;">
                            Siz de deneyimlerinizi paylaşın, meslektaşlarınızdan faydalanın, birlikte daha güçlü bir mali müşavirlik camiası oluşturalım.
                        </p>
                        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse !important; mso-table-lspace: 0pt; mso-table-rspace: 0pt; text-align: center;">
                            <tr>
                                <td align="center" style="mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <a href="https://apps.apple.com/tr/app/maligörüş/id6765759650?l=tr" style="text-decoration: none; display: block; margin: 0 auto 15px auto;">
                                        <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/tr-tr?size=250x83&amp;releaseDate=1314662400&h=656911571477174e5033c4608c5c7075" alt="App Store'dan İndirin" style="height: 60px; width: auto; border: 0;">
                                    </a>
                                    <a href="https://play.google.com/store/apps/details?id=com.maligorus.maligorus" style="text-decoration: none; display: block; margin: 0 auto;">
                                        <img src="https://play.google.com/intl/en_us/badges/static/images/badges/tr_badge_web_generic.png" alt="Google Play'den Alın" style="height: 88px; width: auto; border: 0; margin-top: -14px;">
                                    </a>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>

                <!-- FOOTER -->
                <tr>
                    <td style="background-color: #ffffff; padding: 20px 30px; border-top: 1px solid #eeeeee; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="border-collapse: collapse !important; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                            <tr>
                                <td valign="middle" width="50%" style="mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <strong style="color: #001a4d; font-size: 16px;">[M] MaliGörüş</strong><br>
                                    <span style="color: #4a4a4a; font-size: 12px;">Mali müşavirler için kapalı network platformu</span>
                                </td>
                                <td valign="middle" width="50%" align="right" style="mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                                    <a href="https://www.maligorus.com" style="color: #4a4a4a; text-decoration: none; font-size: 14px; font-weight: 500;">
                                        🌐 www.maligorus.com
                                    </a>
                                </td>
                            </tr>
                        </table>
                    </td>
                <!-- YASAL UYARI VE UNSUBSCRIBE BÖLÜMÜ -->
                <tr>
                    <td style="background-color: #f4f6f9; padding: 20px 30px; text-align: center; mso-table-lspace: 0pt; mso-table-rspace: 0pt;">
                        <p style="color: #888888; margin: 0 0 10px 0; font-size: 11px; line-height: 1.4;">
                            MaliGörüş<br>
                            Bu ticari elektronik ileti, açık kaynaklardan derlenen iletişim bilgileriniz üzerinden tarafınıza mesleki bilgilendirme ve tanıtım amacıyla gönderilmiştir.<br>
                            <a href="https://www.maligorus.com/gizlilik/index.html" style="color: #666666; text-decoration: underline;">Gizlilik ve KVKK Politikası</a>
                        </p>
                        <p style="color: #888888; margin: 0; font-size: 11px;">
                            MaliGörüş ağından gelecekte e-posta almak istemiyorsanız lütfen <a href="{{UNSUBSCRIBE_LINK}}" style="color: #cc0000; text-decoration: underline; font-weight: bold;">buraya tıklayarak abonelikten ayrılın</a>.
                        </p>
                    </td>
                </tr>

            </table>
            <!-- Ana Konteyner Sonu -->
        </td>
    </tr>
</table>

</body>
</html>

`;

serve(async (req) => {
  try {
    // Check if it's a test request
    let body = {};
    try {
      body = await req.json();
    } catch (e) {
      // Body might be empty or invalid JSON, ignore
    }

    const testEmail = body.testEmail;

    let leads = [];
    if (testEmail) {
      console.log(`[Test Mode] Sending test email to ${testEmail}`);
      leads = [{ id: "test-id", name: "Test Kullanıcısı", email: testEmail }];
    } else {
      // 1. Fetch un-emailed leads (Limit to 1 per run to respect user preference)
      const { data: dbLeads, error: fetchError } = await supabase
        .from("marketing_leads")
        .select("id, name, email")
        .eq("is_emailed", false)
        .not("email", "is", null)
        .or("is_unsubscribed.is.null,is_unsubscribed.eq.false")
        .limit(1);

      if (fetchError) throw fetchError;
      leads = dbLeads || [];
    }

    if (leads.length === 0) {
      return new Response(JSON.stringify({ message: "No pending emails to send." }), { headers: { "Content-Type": "application/json" }});
    }

    // 2. Connect to SMTP via nodemailer
    const transporter = nodemailer.createTransport({
      host: SMTP_HOSTNAME,
      port: SMTP_PORT,
      secure: SMTP_PORT === 465, // true for 465, false for other ports (like 587)
      auth: {
        user: SMTP_USERNAME,
        pass: SMTP_PASSWORD,
      },
    });

    const sentLeadIds = [];

    // 3. Send emails
    for (const lead of leads) {
      if (!lead.email) continue;
      
      const unsubscribeLink = `${SUPABASE_URL}/functions/v1/unsubscribe?id=${lead.id}`;
      const emailContent = EMAIL_TEMPLATE.replace("{{UNSUBSCRIBE_LINK}}", unsubscribeLink);
      
      try {
        await transporter.sendMail({
          from: `"MaliGörüş" <${SENDER_EMAIL}>`,
          to: lead.email,
          subject: EMAIL_SUBJECT,
          html: emailContent, 
        });
        
        if (!testEmail) {
           sentLeadIds.push(lead.id);
        }
      } catch (err) {
        console.error(`Failed to send email to ${lead.email}:`, err);
      }
    }

    // 4. Update the sent leads in database (only if not a test)
    if (sentLeadIds.length > 0 && !testEmail) {
      await supabase
        .from("marketing_leads")
        .update({ is_emailed: true, emailed_at: new Date().toISOString() })
        .in("id", sentLeadIds);
    }

    return new Response(JSON.stringify({ 
      success: true, 
      is_test: !!testEmail,
      emails_sent: testEmail ? 1 : sentLeadIds.length 
    }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Email sending error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
