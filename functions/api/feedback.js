/**
 * Cloudflare Pages Function: /api/feedback
 * Handles bug reports, feature ideas, star ratings, and feedback without requiring any VPS or server.
 * Securely forwards submissions to your Discord staff channel via encrypted Webhook URL.
 */

// Feedback rate limiter (max 3 submissions per 10 mins per IP)
const feedbackRateMap = new Map();

function checkFeedbackRateLimit(ip) {
  const now = Date.now();
  const windowMs = 10 * 60 * 1000; // 10 minutes
  const maxPerWindow = 3;

  let timestamps = feedbackRateMap.get(ip) || [];
  timestamps = timestamps.filter(t => now - t < windowMs);

  if (timestamps.length >= maxPerWindow) {
    return false;
  }

  timestamps.push(now);
  feedbackRateMap.set(ip, timestamps);
  return true;
}

const SPAM_REGEX = /\b(casino|crypto|poker|viagra|whatsapp|telegram|giveaway|investment|lottery)\b/i;

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
    const clientIp = request.headers.get('cf-connecting-ip') || request.headers.get('x-real-ip') || 'unknown';

    // 1. Honeypot check for bots
    if (payload.website || payload.hp || payload.mzc_hp) {
      return new Response(JSON.stringify({
        success: true,
        status: "ticket_created",
        ticket_id: "#MZ-FEED-BOT0",
        message: "Feedback received successfully"
      }), { status: 200, headers: corsHeaders });
    }

    const type = (payload.type || 'feedback').toUpperCase();

    // 2. Rate Limiting Check (CONNECT bypasses feedback limit)
    if (type !== 'CONNECT' && !checkFeedbackRateLimit(clientIp)) {
      return new Response(JSON.stringify({
        error: "Too many feedback submissions. Please wait 10 minutes."
      }), { status: 429, headers: corsHeaders });
    }

    const messageContent = (payload.message || payload.issue || '').trim();

    // 3. Message validation & spam filter
    if (!messageContent || messageContent.length < 3) {
      return new Response(JSON.stringify({ error: "Please provide a valid feedback message." }), {
        status: 400,
        headers: corsHeaders
      });
    }

    if (messageContent.length > 2000) {
      return new Response(JSON.stringify({ error: "Message exceeds 2,000 characters." }), {
        status: 400,
        headers: corsHeaders
      });
    }

    if (SPAM_REGEX.test(messageContent)) {
      return new Response(JSON.stringify({ error: "Feedback flagged by spam filter." }), {
        status: 400,
        headers: corsHeaders
      });
    }

    const type = (payload.type || 'feedback').toUpperCase();
    const randSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    const ticketId = `#MZ-${type.slice(0, 4)}-${randSuffix}`;

    const webhookUrl = env.DISCORD_WEBHOOK_URL;
    if (webhookUrl && webhookUrl.startsWith('https://discord.com/api/webhooks/')) {
      const typeColors = {
        'BUG': 0xFF3B30,     // Red
        'IDEA': 0x8B7BFF,    // Purple
        'TALK': 0x0071E3,    // Blue
        'FEEDBACK': 0xFFB800,// Gold
        'CONNECT': 0x0071E3  // Blue
      };

      const stars = payload.stars || payload.rating || 0;
      const starsDisplay = stars > 0 ? "★".repeat(stars) + "☆".repeat(5 - stars) : "Not rated";
      const title = type === 'CONNECT'
        ? `💌 User Connected Email: ${payload.email}`
        : `📬 New Support Submission (${ticketId})`;

      const embed = {
        title: title,
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
