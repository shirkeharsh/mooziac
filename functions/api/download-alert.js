/**
 * Cloudflare Pages Function: /api/download-alert
 * Securely forwards download click events to your Discord webhook without exposing the URL to users.
 */

export async function onRequestPost(context) {
  const { request, env } = context;

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json'
  };

  try {
    const data = await request.json().catch(() => ({}));
    const webhookUrl = env.DISCORD_WEBHOOK_URL;

    // If an encrypted webhook secret is configured, send the alert to Discord
    if (webhookUrl && webhookUrl.startsWith('https://discord.com/api/webhooks/')) {
      const country = request.headers.get('cf-ipcountry') || '';
      const city = request.headers.get('cf-ipcity') || '';
      const region = request.headers.get('cf-region') || '';
      const timezone = request.headers.get('cf-timezone') || '';
      const clientIp = request.headers.get('cf-connecting-ip') || 'Unknown';
      const ua = request.headers.get('user-agent') || '';
      const referer = data.referrer || request.headers.get('referer') || 'Direct';
      const rayId = request.headers.get('cf-ray') || 'N/A';

      // Flag emoji generator
      let flag = '🌐';
      if (country && country.length === 2 && country !== 'XX') {
        const codePoints = country.toUpperCase().split('').map(c => 127397 + c.charCodeAt(0));
        flag = String.fromCodePoint(...codePoints);
      }

      const locationParts = [city, region, country ? `${flag} ${country}` : ''].filter(Boolean);
      const locationStr = locationParts.length > 0 ? locationParts.join(', ') : 'Unknown';

      // Parse macOS architecture / browser
      let clientDevice = 'macOS';
      if (/Macintosh/i.test(ua)) {
        const arch = /Intel/i.test(ua) ? 'Intel / Rosetta' : 'Apple Silicon';
        const match = ua.match(/Mac OS X ([0-9_]+)/);
        const ver = match ? `macOS ${match[1].replace(/_/g, '.')}` : 'macOS';
        clientDevice = `${ver} (${arch})`;
      } else if (/Windows/i.test(ua)) {
        clientDevice = 'Windows';
      }

      let browser = 'Browser';
      if (/Chrome/i.test(ua)) browser = 'Chrome';
      else if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari';
      else if (/Firefox/i.test(ua)) browser = 'Firefox';

      const embed = {
        title: "🚀 New Mooziac Download Clicked!",
        color: 0xFA4059, // Mooziac Coral
        fields: [
          { name: "Button", value: data.btnText || "Download for Mac", inline: true },
          { name: "Section", value: data.section || "Landing Page", inline: true },
          { name: "Platform", value: data.platform || "macOS Universal", inline: true },
          { name: "🌍 Location", value: `${locationStr}${timezone ? ` (${timezone})` : ''}`, inline: true },
          { name: "💻 Device & Browser", value: `${clientDevice} • ${browser}`, inline: true },
          { name: "🖥️ Resolution", value: data.screenRes || "Unknown", inline: true },
          { name: "🌐 Referrer", value: referer, inline: true },
          { name: "🔒 IP & Ray ID", value: `${clientIp} (${rayId})`, inline: true }
        ],
        footer: { text: "Mooziac Cloudflare Edge Telemetry" },
        timestamp: new Date().toISOString()
      };

      await fetch(webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: "Mooziac Downloads",
          avatar_url: "https://mooziac.threeten.site/assets/launch_transparent.png",
          embeds: [embed]
        })
      }).catch(err => console.error("Webhook error:", err));
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: corsHeaders
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err.message }), {
      status: 200,
      headers: corsHeaders
    });
  }
}

export async function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400'
    }
  });
}
