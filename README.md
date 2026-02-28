# Portfolio Mobile Admin

This Flutter application allows you to manage the content of your portfolio website in real-time using Firebase.

## Setup

1. Ensure you have [Flutter](https://flutter.dev/docs/get-started/install) installed and added to your PATH.
2. Run the `setup_mobile.bat` script in this directory.
   - This script will run `flutter pub get` to install dependencies.
   - It will then attempt to run the app using `flutter run`.

## Manual Setup

If you prefer to run commands manually:

```bash
flutter pub get
flutter run
```

## Secure Config (Recommended)

Prefer runtime defines (recommended for production):

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=... \
  --dart-define=GROQ_API_KEY=... \
  --dart-define=ADMIN_EMAIL=... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=... \
  --dart-define=PREMIUM_MONTHLY_PAYMENT_URL=... \
  --dart-define=PREMIUM_YEARLY_PAYMENT_URL=... \
  --dart-define=RAZORPAY_API_KEY=... \
  --dart-define=WEB_BASE_URL=...
```

You can also use:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

Where `dart_defines.json` contains:

```json
{
  "GEMINI_API_KEY": "...",
  "GROQ_API_KEY": "...",
  "ADMIN_EMAIL": "...",
  "GOOGLE_SERVER_CLIENT_ID": "...",
  "PREMIUM_MONTHLY_PAYMENT_URL": "...",
  "PREMIUM_YEARLY_PAYMENT_URL": "...",
  "RAZORPAY_API_KEY": "...",
  "WEB_BASE_URL": "..."
}
```

`.env.example` is included as a key reference template.
`.env` fallback is still supported for local development compatibility.

## Troubleshooting

- **"flutter" is not recognized...**: Make sure Flutter is installed and its `bin` directory is in your system PATH.
- **Firebase errors**: Ensure your `firebase_options.dart` is correctly configured (it should be if you followed the setup).
