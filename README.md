# Reach 📍
**Never reach late. The Smart Commute Alarm that works backwards.**

Reach is a smart commute assistant built with Flutter. Unlike standard alarms, Reach focuses on **when you need to arrive**, calculating your precise **"Leave By"** time dynamically based on real-time traffic, weather conditions, and your chosen mode of transport.

> **"Don't leave when you think you should. Leave when you NEED to."**

---

## 🚀 Features

* **🧠 Smart Time Calculation:** Works backwards from your *Target Arrival Time*.
* **⛅ Weather & Traffic Aware:** automatically adds buffer time if it detects rain or heavy traffic (via Mappls/MapMyIndia & OpenWeather).
* **🔔 Dual-Stage Alarms:**
    1.  **"Pack Up" Alert:** Nudges you 15 minutes before departure so you have time to get ready.
    2.  **"Leave Now" Alarm:** Full-screen critical alert when traffic dictates you must move *now*.
* **📅 Calendar Sync:** Automatically scans your device calendar for upcoming events and suggests setting reach alarms for them.
* **🌗 Dynamic Theming:** UI adapts automatically based on the time of day (Navy for Morning, Grey for Day, Pitch Black for Night).
* **📍 Navigation Handoff:** One-tap navigation to Google Maps or Mappls.
* **⚡ Premium Feel:** Haptic feedback on interactions, swipe-to-delete with undo, and smooth animations.

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **State Management:** Native `setState` & `WidgetsBindingObserver` for lifecycle management.
* **Background Services:**
    * `android_alarm_manager_plus` for precise background execution.
    * `flutter_local_notifications` for heads-up alerts.
* **Location & APIs:** `geolocator`, `http` (Custom Traffic/Weather Services).
* **Persistence:** `shared_preferences` for local data caching.

## 📸 Screenshots

| **Home (Light)** | **Home (Dark)** |
|:---:|:---:|
| <img src="./screenshots/1.jpeg" width="300" /> | <img src="./screenshots/2.jpeg" width="300" /> |

| **Add Trip (Light)** | **Add Trip (Dark)** |
|:---:|:---:|
| <img src="./screenshots/3.jpeg" width="300" /> | <img src="./screenshots/4.jpeg" width="300" /> |

## 🏁 Getting Started

1.  **Clone the repo:**
    ```bash
    git clone [https://github.com/Sparsh5126/Reach.git](https://github.com/Sparsh5126/Reach.git)
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Setup Keys (Optional):**
    Create a `.env` file in the root and add your API keys:
    ```env
    MAPPLS_API_KEY=your_key_here
    ```
4.  **Run the app:**
    ```bash
    flutter run
    ```

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## 📄 License

This project is licensed under the MIT License.