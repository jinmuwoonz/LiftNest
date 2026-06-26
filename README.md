# LiftNest 🏋️‍♂️

LiftNest is a modern, beautifully designed Flutter application built specifically for **home gym owners and those who workout at home**. When you're lifting at home, you don't always have an infinite supply of commercial gym plates. LiftNest helps you manage your limited plate inventory, mix and match equipment, and automatically calculate exactly what plates you need to load onto your bar or dumbbells to hit your target weight.

## ✨ Features

- **Inventory Management**: Create different inventories (e.g., "Standard Barbell Setup", "Adjustable Dumbbells") and track exactly which plates you own.
- **Custom Plate Colors**: Assign standard Olympic colors or pick custom colors for each weight plate in your inventory.
- **Smart Plate Calculator**: Enter your target weight, select your inventories (pool them together or keep them separate!), and let the app calculate exactly which plates to use based solely on what you own.
- **Real-Time Visual Barbell**: Instantly see a colorful, centered visual representation of the barbell and plates update in real-time as you type your target weight.
- **Manual Plate Selection**: Want to use specific plates? Bypass the calculator and manually select exactly which plates you want to load, automatically updating your total weight.
- **Dual Bar & No Bar Support**: Calculate plates for a single heavy barbell, split the weight across two separate bars (for adjustable dumbbells), or calculate pure plate weight without a bar.
- **Bodyweight & Weighted Exercises**: Toggle whether an exercise requires weight or if it's just a bodyweight movement.
- **Settings & Preferences**: Customize your app with your preferred main weight unit (KG or LB).
- **Dark Mode Aesthetic**: A sleek, premium dark theme with vibrant orange accents designed specifically to look great in your home gym environment.

## 📱 Screenshots & Visuals
*(No screenshots yet)*

## 🛠️ Built With

- [Flutter](https://flutter.dev/) - UI Toolkit
- [Dart](https://dart.dev/) - Programming Language
- [sqflite](https://pub.dev/packages/sqflite) - Local Database for offline storage
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local storage for user settings

## 🚀 Getting Started

To run this project locally, make sure you have Flutter installed.

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/liftnest.git
   ```
2. Navigate into the project directory:
   ```bash
   cd liftnest
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app (in debug mode):
   ```bash
   flutter run
   ```
5. Build the production-ready APK:
   ```bash
   flutter build apk
   ```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
