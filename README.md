# Runner 🏃

A **2D Endless Runner** game built with **Godot 4.x** (GDScript). Dodge obstacles, beat your high score, and challenge yourself as the speed increases over time!

---

## 🎮 Game Features

| Feature | Details |
|---------|---------|
| **Genre** | 2D Endless Runner |
| **Engine** | Godot 4.x |
| **Controls** | Tap screen or press **Spacebar** to jump (double-jump supported!) |
| **Scoring** | Distance-based score, increases every 0.1 seconds |
| **Difficulty** | Speed gradually increases over time |
| **Platforms** | iOS & Android export presets included |

### Gameplay
- Your character auto-runs to the right
- Tap/click or press **Space** to jump over obstacles
- You can **double-jump** for extra height
- Obstacles come faster as you progress
- Colliding with an obstacle ends the run — beat your high score!

---

## 🚀 How to Open and Run in Godot

### Requirements
- **Godot 4.2+** — Download free from [godotengine.org](https://godotengine.org/download)

### Steps
1. **Clone the repository**
   ```bash
   git clone https://github.com/bhavyat81/runner.git
   cd runner
   ```

2. **Open in Godot**
   - Launch Godot 4.x
   - Click **Import** in the Project Manager
   - Browse to the cloned folder and select `project.godot`
   - Click **Import & Edit**

3. **Run the game**
   - Press **F5** (or click the ▶ Play button) to run the main scene
   - The game starts at the Main Menu

### Controls
| Action | Control |
|--------|---------|
| Jump | Space / Screen Tap / Screen Click |
| Double Jump | Space / Tap again while in the air |
| Pause | P key / ⏸ button in-game |

---

## 📱 How to Export for Android

### Prerequisites
1. **Android SDK** — Install via Android Studio or command line tools
2. **Java JDK** — JDK 17 recommended
3. **Godot Android Build Templates**:
   - In Godot: **Project → Install Android Build Template**

### Export Steps
1. Open Godot with this project
2. Go to **Project → Export**
3. Select the **Android** preset
4. **Set up signing** (required for publishing):
   - Create a keystore: `keytool -genkey -v -keystore runner.keystore -alias runner -keyalg RSA -keysize 2048 -validity 10000`
   - In the export preset, set **Keystore** path and passwords
5. Click **Export Project**
6. Choose **APK** (for sideloading/testing) or **AAB** (for Google Play)

### Google Play Publishing
1. Create a Google Play Developer account ($25 one-time fee)
2. Create a new app in the [Google Play Console](https://play.google.com/console)
3. Upload the signed AAB file
4. Fill in store listing details and submit for review

---

## 🍎 How to Export for iOS

### Prerequisites
1. **macOS** with **Xcode 14+** installed
2. **Apple Developer Account** ($99/year at [developer.apple.com](https://developer.apple.com))
3. **Godot iOS Export Templates** — download from Godot release page

### Export Steps
1. Open Godot with this project on macOS
2. Go to **Project → Export**
3. Select the **iOS** preset
4. Fill in your:
   - **App Store Team ID** (from Apple Developer portal)
   - **Bundle Identifier**: `com.bhavyat81.runner`
   - **Provisioning Profile UUIDs** (create in Apple Developer portal)
5. Click **Export Project** — this creates an Xcode project

### App Store Publishing
1. Open the exported `.xcodeproj` in Xcode
2. Select your development team and signing certificates
3. Go to **Product → Archive**
4. In **Organizer**, click **Distribute App**
5. Choose **App Store Connect** and follow the prompts
6. Submit for App Store Review in [App Store Connect](https://appstoreconnect.apple.com)

---

## 📁 Project Structure

```
runner/
├── project.godot              # Godot project configuration
├── export_presets.cfg         # Android & iOS export settings
├── icon.svg                   # App icon
├── README.md
├── scenes/
│   ├── main_menu.tscn         # Title screen
│   ├── game.tscn              # Main gameplay scene
│   ├── player.tscn            # Player character
│   ├── obstacle.tscn          # Obstacle prefab
│   └── game_over.tscn         # Standalone game over screen
└── scripts/
    ├── game_manager.gd        # Global autoload: state, score, transitions
    ├── main_menu.gd           # Main menu logic
    ├── game.gd                # Game scene controller & obstacle spawner
    ├── player.gd              # Player physics & jump logic
    ├── obstacle.gd            # Obstacle movement & collision
    └── game_over.gd           # Game over screen logic
```

---

## 🛠️ Technical Notes

- **Engine**: Godot 4.x (GDScript)
- **Player**: `CharacterBody2D` with gravity-based physics
- **Obstacles**: `Area2D` spawned by a `Timer` node with randomized intervals
- **Scoring**: Increments every 0.1 seconds via a `Timer`
- **Difficulty**: `GameManager.current_speed` increases from 300 to 700 px/s
- **High Score**: Saved to `user://save_data.json`
- **Touch Input**: `InputEventScreenTouch` mapped to the `jump` action
- **Display**: 1280×720, `canvas_items` stretch with `expand` aspect ratio for mobile

---

## 📸 Screenshots

*Coming soon — open the project in Godot and press F5 to see it in action!*

---

## 📄 License

MIT License — feel free to use and modify!
