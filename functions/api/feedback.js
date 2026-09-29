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

    const randSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    const ticketId = `#MZ-${type.slice(0, 4)}-${randSuffix}`;

    const webhookUrl = env.DISCORD_WEBHOOK_URL;
    if (webhookUrl && webhookUrl.startsWith('https://discord.com/api/webhooks/')) {
      const typeColors = {
        'BUG': 0xFF3B30,     // Red
        'IDEA': 0x8B7BFF,    // Purple
        'TALK': 0x0071E3,    // Blue
        'FEEDBACK': 0xFFB800,// Gold
        'CONNECT': 0x34C759  // Emerald Green
      };

      // Extract rich Cloudflare edge metadata
      const country = request.headers.get('cf-ipcountry') || '';
      const city = request.headers.get('cf-ipcity') || '';
      const region = request.headers.get('cf-region') || '';
      const timezone = request.headers.get('cf-timezone') || '';
      const ua = request.headers.get('user-agent') || '';
      const referer = request.headers.get('referer') || 'Direct';
      const rayId = request.headers.get('cf-ray') || 'N/A';

      // Flag emoji generator
      let flag = '🌐';
      if (country && country.length === 2 && country !== 'XX') {
        const codePoints = country.toUpperCase().split('').map(c => 127397 + c.charCodeAt(0));
        flag = String.fromCodePoint(...codePoints);
      }

      // Location string
      const locationParts = [city, region, country ? `${flag} ${country}` : ''].filter(Boolean);
      const locationStr = locationParts.length > 0 ? locationParts.join(', ') : 'Unknown';

      // Parse macOS architecture / browser
      let clientDevice = 'macOS';
      if (/Macintosh/i.test(ua)) {
        const arch = /Intel/i.test(ua) ? 'Intel / Rosetta' : 'Apple Silicon';
        const match = ua.match(/Mac OS X ([0-9_]+)/);
        const ver = match ? `macOS ${match[1].replace(/_/g, '.')}` : 'macOS';
        clientDevice = `${ver} (${arch})`;
      } else if (/iPhone|iPad/i.test(ua)) {
        clientDevice = 'iOS Mobile';
      } else if (/Windows/i.test(ua)) {
        clientDevice = 'Windows';
      }

      let browser = 'Browser';
      if (/Chrome/i.test(ua)) browser = 'Chrome';
      else if (/Safari/i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari';
      else if (/Firefox/i.test(ua)) browser = 'Firefox';
      else if (/Edg/i.test(ua)) browser = 'Edge';

      const stars = payload.stars || payload.rating || 0;
      const starsDisplay = stars > 0 ? "★".repeat(stars) + "☆".repeat(5 - stars) : "Not rated";
      
      let title = `📬 New Support Submission (${ticketId})`;
      if (type === 'CONNECT') title = `💌 User Connected Email (${payload.email})`;
      else if (type === 'FEEDBACK') title = `⭐ New Rating Feedback: ${starsDisplay} (${ticketId})`;
      else if (type === 'BUG') title = `🐛 New Bug Report (${ticketId})`;
      else if (type === 'IDEA') title = `💡 New Feature Idea (${ticketId})`;

      const fields = [
        { name: "Ticket ID", value: ticketId, inline: true },
        { name: "Category", value: type, inline: true },
        { name: "Rating", value: starsDisplay, inline: true },
        { name: "Name", value: payload.name || "Anonymous", inline: true },
        { name: "Email", value: payload.email || "No email provided", inline: true },
        { name: "🌍 Location", value: `${locationStr}${timezone ? ` (${timezone})` : ''}`, inline: true },
        { name: "💻 Device / OS", value: `${payload.macos || clientDevice} • ${browser}`, inline: true },
        { name: "🌐 Referrer", value: referer, inline: true },
        { name: "🔒 IP & Ray ID", value: `${clientIp} (${rayId})`, inline: true },
        { name: "📝 Message / Details", value: payload.message || payload.issue || "No message content", inline: false }
      ];

      const embed = {
        title: title,
        color: typeColors[type] || 0x34C759,
        fields: fields,
        footer: { text: "Mooziac Support Portal • Cloudflare Edge" },
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
