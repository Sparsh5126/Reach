# Reach 📍
**Never miss your commute again.**

**Reach.** is a context-aware alarm application designed to eliminate "late-for-arrival" anxiety. By integrating live traffic and meteorological data, it dynamically calculates your departure time, ensuring you reach your destination on time, every time.

---

## 📱 User Interface

<p align="center">
  <img src="screenshots/home-page.jpeg" height="450px" style="margin-right: 10px;" />
  <img src="screenshots/new-trip.jpeg" height="450px" style="margin-right: 10px;" />
  <img src="screenshots/new-trip-car.jpeg" height="450px" style="margin-right: 10px;" />
  <img src="screenshots/new-trip-flight.jpeg" height="450px" />
</p>

<p align="center">
  <i>Dashboard &nbsp; | &nbsp; Train Mode &nbsp; | &nbsp; Car Mode &nbsp; | &nbsp; Flight Pickup</i>
</p>

## 🧠 Key Features in v2.0

* **Dynamic Traffic Engine**: Integrates with the **OSRM API** to calculate real-world travel duration based on live traffic between coordinates.
* **Weather-Aware Logic**: Automatically detects rain via **OpenWeather API** and adds a 15–30 minute safety cushion to the schedule.
* **Motorcycle Optimization**: Specialized logic for bikers, doubling the rain buffer to account for the increased complexity of riding in inclement weather.
* **Pickup/Departure Toggle**: Specific modes for trains and flights that include extra buffers for airport/station navigation.
* **The "Pack" Window**: A custom 10-minute preparation notification triggered before the actual departure alarm.
* **Exact Alarm Reliability**: Implements Android "Exact Alarm" permissions to ensure alerts trigger precisely, even when the device is idle.

---

## 🛠 Tech Stack

* **Frontend**: Flutter (Dart) with a custom high-contrast dark theme.
* **APIs**: OSRM (Routing), OpenWeather (Weather), Photon (Geocoding Search).
* **Storage**: **SharedPreferences** for persistent local schedules.
* **Notifications**: `flutter_local_notifications` with `fullScreenIntent` for system-level alarms.

---

## 🚀 Installation

1.  **Download**: Grab the latest APK from the [Releases](https://github.com/Sparsh5126/Reach./releases) section.
2.  **Permissions**: Grant "Alarms & Reminders" when prompted to enable exact scheduling.

---
