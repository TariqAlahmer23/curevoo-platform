# CureVoo Doctor

Flutter app for the CureVoo doctor dashboard.

## Local Web Development

Use a fixed web port while developing so browser storage keeps the same origin
between runs. This helps the saved auth token persist across app restarts.

```bash
flutter run -d chrome --web-port 5000
```

Then open:

```text
http://localhost:5000
```

The app uses clean browser paths such as:

```text
/dashboard
/appointments
/patients
/schedule
/profile
```

## Checks

Run these before committing routing, auth, or UI changes:

```bash
flutter analyze
flutter test
flutter build web --release
```

## Web Build

For local web builds:

```bash
flutter build web --release
```

The app currently keeps the default API base URL:

```text
http://curevoo.talents-we-trust.tech:3000/api
```

To override the API URL for another environment, pass it at build time:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-api-domain.com/api
```

## Hosting Clean URLs

Because the app uses path-based URLs, production hosting must serve
`build/web/index.html` for every app route. Without this, refreshing a direct
route such as `/patients` can return a 404 from the host.

Example fallback rules:

Firebase Hosting:

```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

Netlify:

```text
/* /index.html 200
```

Vercel:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```
