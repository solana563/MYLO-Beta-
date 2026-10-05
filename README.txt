milo. - installable app
=======================

What's in this folder
  index.html            the app
  manifest.webmanifest  app name, icons, shortcuts, "open audio files with milo." on desktop
  sw.js                 service worker (makes the app open offline)
  icons/                app icons made from your logo (any, maskable, Apple touch, favicon, SVG)
  splash/               splash screen made from your image (splash.jpg + iPhone/iPad startup images)

How to get it on a phone or computer
  An installable web app has to be served from https (or from localhost).
  1. Put this whole folder on any static host. Free options: Netlify Drop (drag the folder onto app.netlify.com/drop),
     GitHub Pages, Cloudflare Pages, Vercel.
  2. Open the https address:
       Android / Chrome, Edge:  menu > Install app  (or the install button in Profile > Install milo.)
       iPhone / iPad (Safari):  Share > Add to Home Screen
       Desktop Chrome / Edge:   install icon at the right of the address bar
  3. To try it on your computer first, open a terminal in this folder and run:
       python3 -m http.server 8080
     then visit http://localhost:8080

Notes
  - Songs you add are stored inside the installed app's own browser storage and stay between launches.
  - Android shows its own black splash with your icon for a moment before the milo. splash image appears;
    iPhone/iPad show your splash image straight away.
  - If you change index.html later, change the version name in sw.js (milo-v1 -> milo-v2) so installed copies update.
  - To wrap this as a Play Store / Microsoft Store / App Store package, upload the hosted address to pwabuilder.com.

If installing doesn't work
  - "Install" only appears when the app is opened from an https address (or http://localhost). Opening index.html straight from your
    files app, or from a chat/preview link, can't be installed. Profile > Install milo. tells you which case you are in.
  - Keep the whole folder together. The service worker (sw.js), manifest.webmanifest, icons/ and splash/ must sit next to index.html.
  - Android Chrome: if the Install option is missing, reload once after the first visit.
  - iPhone/iPad: use Safari (not Chrome) and Share > Add to Home Screen.
