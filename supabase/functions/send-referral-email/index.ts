import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") || "";

serve(async (req) => {
  try {
    const { candidate_email, candidate_name, referrer_name, type } = await req.json();

    if (!candidate_email || !candidate_name) {
      return new Response(JSON.stringify({ error: "Eksik parametreler" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const isReferral = type === "friend_referral";
    const subject = isReferral
      ? `${referrer_name} sizi MaliGörüş'e davet ediyor!`
      : "MaliGörüş'e Hoş Geldiniz!";

    const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; }
        .header { background: linear-gradient(135deg, #1a237e, #3949ab); padding: 40px 30px; text-align: center; }
        .header h1 { color: white; margin: 0; font-size: 28px; }
        .content { padding: 30px; }
        .greeting { font-size: 18px; color: #1a237e; font-weight: bold; margin-bottom: 16px; }
        .message { color: #555; line-height: 1.7; font-size: 15px; }
        .features { background: #f8f9ff; border-radius: 12px; padding: 20px; margin: 24px 0; }
        .feature { display: flex; align-items: center; margin-bottom: 12px; }
        .feature-icon { width: 30px; height: 30px; background: #e8eaf6; border-radius: 8px; display: flex; align-items: center; justify-content: center; margin-right: 12px; }
        .cta-section { text-align: center; margin: 30px 0; }
        .cta-button { display: inline-block; background: #3949ab; color: white !important; padding: 14px 32px; border-radius: 12px; text-decoration: none; font-weight: bold; }
        .footer { background: #f8f9ff; padding: 20px 30px; text-align: center; color: #999; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header"><h1>MaliGörüş</h1></div>
        <div class="content">
          <p class="greeting">Merhaba ${candidate_name},</p>
          ${isReferral 
            ? `<p class="message"><strong>${referrer_name}</strong> sizi MaliGörüş platformuna davet ediyor! Bu platform, mali müşavirler için özel profesyonel bir ağdır.</p>`
            : `<p class="message">MaliGörüş'e hoş geldiniz! Kaydınız başarıyla oluşturuldu.</p>`
          }
          <div class="features">
            <h3 style="color: #1a237e; margin-top: 0;">Neler yapabilirsiniz?</h3>
            <p>• Mesleki anketlere katılın<br>• Güncel konuları tartışın<br>• Uzmanlara danışın<br>• Meslektaşlarınızla mesajlaşın</p>
          </div>
          <div class="cta-section">
            <a href="https://maligorus.app" class="cta-button">Uygulamayı Keşfet</a>
          </div>
        </div>
        <div class="footer"><p>© 2026 MaliGörüş</p></div>
      </div>
    </body>
    </html>
    `;

    // Brevo API Çağrısı
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "accept": "application/json",
        "api-key": BREVO_API_KEY,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        sender: { name: "MaliGörüş", email: "noreply@maligorus.app" },
        to: [{ email: candidate_email, name: candidate_name }],
        subject: subject,
        htmlContent: htmlContent,
      }),
    });

    const result = await response.json();

    return new Response(JSON.stringify({ success: true, result }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
