/**
 * Cloudflare Pages Function: /api/feedback
 * Handles bug reports, feature ideas, star ratings, and feedback without requiring any VPS or server.
 * Securely forwards submissions to your Discord staff channel via encrypted Webhook URL.
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
    const payload = await request.json().catch(() => ({}));
    const type = (payload.type || 'feedback').toUpperCase();
    const randSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    const ticketId = `#MZ-${type.slice(0, 4)}-${randSuffix}`;

    const webhookUrl = env.DISCORD_WEBHOOK_URL;
    if (webhookUrl && webhookUrl.startsWith('https://discord.com/api/webhooks/')) {
      const typeColors = {
        'BUG': 0xFF3B30,     // Red
        'IDEA': 0x8B7BFF,    // Purple
        'TALK': 0x0071E3,    // Blue
        'FEEDBACK': 0xFFB800 // Gold
      };

      const stars = payload.stars || payload.rating || 0;
      const starsDisplay = stars > 0 ? "★".repeat(stars) + "☆".repeat(5 - stars) : "Not rated";

      const embed = {
        title: `📬 New Support Submission (${ticketId})`,
        color: typeColors[type] || 0x34C759,
        fields: [
          { name: "Type", value: type, inline: true },
          { name: "Rating", value: starsDisplay, inline: true },
          { name: "Name", value: payload.name || "Anonymous", inline: true },
          { name: "Email", value: payload.email || "No email provided", inline: true },
          { name: "macOS System", value: payload.macos || "macOS 13+", inline: true },
          { name: "Message", value: payload.message || payload.issue || "No message content", inline: false }
        ],
        footer: { text: "Mooziac Support Portal" },
        timestamp: new Date().toISOString()
      };

      await fetch(webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: "Mooziac Support Tickets",
          avatar_url: "https://mooziac.threeten.site/assets/launch_transparent.png",
          embeds: [embed]
        })
      }).catch(err => console.error("Discord Webhook Error:", err));
    }

    return new Response(JSON.stringify({
      success: true,
      status: 'ticket_created',
      ticket_id: ticketId,
      message: 'Feedback received successfully'
    }), {
      status: 200,
      headers: corsHeaders
    });
  } catch (err) {
    return new Response(JSON.stringify({
      error: 'Failed to process feedback',
      details: err.message
    }), {
      status: 500,
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
