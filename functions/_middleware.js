export async function onRequest(context) {
  const url = new URL(context.request.url);
  const pathname = url.pathname.toLowerCase();

  // Block access to dotfiles (.env, .git, etc.) and private files
  if (
    pathname.startsWith('/.') ||
    pathname.includes('/.env') ||
    pathname.endsWith('.env') ||
    pathname.includes('ticket') ||
    pathname.includes('backup')
  ) {
    return new Response('404 Not Found', {
      status: 404,
      headers: {
        'Content-Type': 'text/plain',
        'Cache-Control': 'no-store, no-cache, must-revalidate',
      },
    });
  }

  // Continue to static assets or API functions
  const response = await context.next();
  return response;
}
