import type { VercelRequest, VercelResponse } from '@vercel/node';

export default function handler(req: VercelRequest, res: VercelResponse) {
  const { code } = req.query;

  if (!code) {
    return res.status(400).send('Missing authorization code.');
  }

  // Redirect the user's browser to the custom app scheme
  // This breaks out of the web browser and forces Android/iOS to open the app
  const appDeepLink = `eventzone://oauth-callback?code=${code}`;

  // We can use a 302 redirect, or output a simple HTML page with JS redirection.
  // HTML + JS is often more reliable on mobile devices to trigger the intent.
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Redirecting to Eventzone...</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body { font-family: sans-serif; text-align: center; padding-top: 50px; background: #1a1a2e; color: white; }
        a { color: #007bff; text-decoration: none; padding: 12px 24px; background: #2a2a4e; border-radius: 8px; display: inline-block; margin-top: 20px;}
      </style>
      <script>
        window.onload = function() {
          window.location.href = "${appDeepLink}";
          setTimeout(function() {
             document.getElementById('manual-btn').style.display = 'inline-block';
          }, 1500);
        };
      </script>
    </head>
    <body>
      <h2>Successfully Authenticated!</h2>
      <p>Redirecting you back to the Eventzone app...</p>
      <a id="manual-btn" href="${appDeepLink}" style="display:none;">Click here if the app doesn't open</a>
    </body>
    </html>
  `;

  res.setHeader('Content-Type', 'text/html');
  return res.status(200).send(html);
}
