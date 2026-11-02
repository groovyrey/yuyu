# Yuyu

Yuyu is a Mobile Legends: Bang Bang (MLBB) skin injector for Android. It lets you browse heroes and skins, favorite skins, and inject custom skins into the game's asset files.

> Developed and maintained by **Dev Sunrey**.

## Features

- **Heroes browser** — browse all heroes with portraits, roles, lanes, prices (battle points + diamonds), and skill info
- **Class filters** — quick filter by hero class (Tank, Fighter, Assassin, Mage, Marksman, Support)
- **Skins catalog** — view every skin per hero, with images, and inject the ones you want
- **Skin-to-Skin transforms** — morph an owned skin into another with a single tap
- **Favorites** — star skins and inject them all in one go from the Favorites tab
- **Advanced Restore** - clears the game's repair markers and re-injects every skin currently marked active
- **Step progress** - download, validation, extraction, and cleanup are reported per skin instead of a spinner
- **Shizuku support** — elevated file access on Android 11+ so the app can modify the game's sandboxed data folder

## Requirements

- Android 8.0+ (API 26+)
- Mobile Legends: Bang Bang installed
- [Shizuku](https://shizuku.rikka.app) running with permission granted (required on Android 11+ to access the game's files)

## How it works

Skins are downloaded from the Yuyu data server, decrypted (AES-256-CBC), and their asset packs (`Art/android/.../*.unity3d`) are extracted into the game's `assets` folder. The engine can reach that folder directly on older Android versions, or through a Shizuku user service on newer ones.

When a skin is injected, Yuyu records the files it wrote for that hero. The Heroes and Favorites tabs use that record to show which skin is active, and the next injection removes files that belonged to the previous skin. If extraction fails partway through, the files written by that attempt are deleted so the game is not left with a mix of skins.

## Usage

1. Install the APK from the [Releases](../../releases) page.
2. Grant storage access when prompted.
3. Install and start Shizuku, then grant Yuyu permission in Settings.
4. Open the **Heroes** tab, pick a hero, and tap **Inject** on a skin.
5. Favorited skins can be injected all at once from the **Favorites** tab.

## Disclaimer

This project is for educational purposes only. All game data and skins belong to their respective owners. Use at your own risk.
