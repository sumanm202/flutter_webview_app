# First Finance Flutter App

A full-screen Flutter app that loads the [First Finance Website](https://firstfinance.xpresspaisa.in/home.php) in a secure WebView, supports Firebase Cloud Messaging (FCM), and integrates features like local notifications, file picker, and permission handling.

## 🚀 Features

- 🌐 Full-screen WebView (via `flutter_inappwebview`)
- 🔔 Firebase Cloud Messaging push notifications
- 📦 Local notifications via `flutter_local_notifications`
- 🧠 Smart navigation for `tel:`, `mailto:`, and `WhatsApp` links
- 🖼️ File upload & media picker support
- 🔐 Permissions: camera, microphone, storage, notifications
- 🔄 JavaScript handler to register FCM token via `onLogin`
- 📉 Reduced APK size using ProGuard
- 🎯 Android support with hybrid composition

## 🛠️ Technologies

- Flutter 3.7.2
- Firebase Core & Messaging
- flutter_inappwebview
- flutter_local_notifications
- permission_handler
- url_launcher
- http

## 📦 Setup

### 1. Clone the repo

```bash
git clone https://github.com/sumanm202/first-finance-flutter-app.git
cd first-finance-flutter-app
