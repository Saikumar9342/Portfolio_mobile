# Portfolio Mobile Admin

This Flutter application allows you to manage the content of your portfolio website in real-time using Firebase.

## Setup

1.  Ensure you have [Flutter](https://flutter.dev/docs/get-started/install) installed and added to your PATH.
2.  Run the `setup_mobile.bat` script in this directory.
    - This script will run `flutter pub get` to install dependencies.
    - It will then attempt to run the app using `flutter run`.

## Manual Setup

If you prefer to run commands manually:

```bash
flutter pub get
flutter run
```

## Troubleshooting

-   **"flutter" is not recognized...**: Make sure Flutter is installed and its `bin` directory is in your system PATH.
-   **Firebase errors**: Ensure your `firebase_options.dart` is correctly configured (it should be if you followed the setup).
