# LiftNest 🏋️‍♂️

LiftNest is a modern, beautifully designed Flutter application built specifically for **home gym owners and those who workout at home**. When you're lifting at home, you don't always have an infinite supply of commercial gym plates. LiftNest helps you manage your limited plate inventory, mix and match equipment, and automatically calculate exactly what plates you need to load onto your bar or dumbbells to hit your target weight.

## ✨ Features

### 🗂️ Inventory Management
- Create multiple inventories (e.g., "Standard Barbell Setup", "Adjustable Dumbbells") and track exactly which plates you own.
- Assign standard Olympic colors or pick custom colors for each weight plate.
- **Per-inventory settings**: Each inventory has its own independent bar setup, bar weight, and weight calculation mode (auto or manual).

### 🧮 Smart Plate Calculator
- Enter your target weight, select one or more inventories, and the app calculates exactly which plates to load based on what you own.
- **Pool inventories** together for a combined plate set, or keep them **separate** with individual calculations shown side by side.
- A dedicated **Quick Calculator** screen is also available for on-the-fly plate math without navigating to a workout.

### 📊 Barbell Visualization
- A real-time, colorful barbell visualization updates as you configure weights.
- Plates are rendered in the order they are added (most recently added plate shown last, matching how you'd actually load the bar).
- The visualization correctly centers itself in all layout contexts.
- **Global unit awareness**: plate labels and summary text (Per side / Plates total) always display in your preferred unit (kg or lb).

### 🏋️ Exercise Configuration
- **Needs Weight toggle**: Mark an exercise as bodyweight or weighted.
- **Time-Based Exercises**: Toggle off "Needs Repetitions" to configure exercises (e.g., planks, holds) that use a duration per set instead of a rep count.
- **Manual Plate Selection**: Bypass the calculator and hand-pick exactly which plates to load, with the total weight calculated accordingly.
- **Dual Bar (Dumbbell / Cable) support**: When two bars are selected, the total weight automatically multiplies the loaded plates by 2.
- **Primary Inventory ordering**: In the workout detail carousel, each exercise's primary (first-selected) inventory is shown first.
- Clean visual separation between multiple inventories on a single exercise.

### 📋 Workout Detail Screen
- Each exercise row shows a full weight summary: barbell visualization, total weight, per-side or plates-total breakdown, sets × reps (or duration), rest time, and inventory name(s).
- Multi-inventory exercises use a swipeable **carousel** that shows all the same metadata as single-inventory exercises.
- Plate totals are always displayed, including for dual-bar and manual-weight configurations.

### ⚙️ Settings & Preferences
- Choose your preferred weight unit: **KG or LB**.
- The entire app — visualizations, labels, summaries, and input fields — respects the selected unit globally.

### 🎨 Design
- Sleek, premium dark theme with vibrant orange accents designed to look great in a home gym environment.
- Smooth micro-animations and interactive elements throughout.

---

## 🛠️ Built With

- [Flutter](https://flutter.dev/) - UI Toolkit
- [Dart](https://dart.dev/) - Programming Language
- [sqflite](https://pub.dev/packages/sqflite) - Local Database for offline storage
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local storage for user settings

---

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
   flutter build apk --release
   ```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
