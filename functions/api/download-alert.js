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
      const embed = {
        title: "🚀 New Mooziac Download Clicked!",
        color: 0xFA4059, // Mooziac Coral
        fields: [
          { name: "Button", value: data.btnText || "Download for Mac", inline: true },
          { name: "Section", value: data.section || "Landing Page", inline: true },
          { name: "Platform", value: data.platform || "macOS", inline: true },
          { name: "Screen Resolution", value: data.screenRes || "Unknown", inline: true },
          { name: "Language", value: data.language || "en", inline: true },
          { name: "Referrer", value: data.referrer || "Direct", inline: false }
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
