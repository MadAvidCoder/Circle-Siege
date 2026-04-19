# Circle Siege
![Hackatime](https://hackatime-badge.hackclub.com/U081TBVQLCX/Circle-Seige)
![License](https://img.shields.io/github/license/madavidcoder/circle-siege)
![Created At](https://img.shields.io/github/created-at/madavidcoder/circle-siege)
![Top Language](https://img.shields.io/github/languages/top/madavidcoder/circle-siege)
![Commits](https://img.shields.io/github/commit-activity/t/madavidcoder/circle-siege)

A rhythm-based dodger game, based on your choice of music via live system audio input!

![hero](https://cdn.hackclub.com/019da581-5aa3-78f1-a481-be870bc63e2f/screenshot_2026-04-19_212123.png)

| ![img1](https://cdn.hackclub.com/019da581-6ca9-7cc6-aadd-48670f8cc483/screenshot_2026-04-19_212107.png) | ![img2](https://cdn.hackclub.com/019da581-5f18-7b77-ba2a-c4d300cb44fd/screenshot_2026-04-19_212144.png) | ![img3](https://cdn.hackclub.com/019da581-63e6-7cbb-b14f-fecb81f42eba/screenshot_2026-04-19_212304.png) |
|:-------------------------------------------------------------------------------------------------------:|:-------------------------------------------------------------------------------------------------------:|:-------------------------------------------------------------------------------------------------------:|
|                                              **Main Menu**                                              |                                       **Alternate Colour Theme**                                        |                                         **High-Contrast Mode**                                          |

### Download it [here](https://github.com/MadAvidCoder/Circle-Siege/releases/latest)!

Circle Siege is a fast-paced, rhythm based dodging game where projectile patterns adapt to the music! Choose between a demo track, file of your choice, or live system audio loopback (e.g. from Spotify). Dodge the incoming obstacles while the timing and intensity is shaped by the music. React, adapt, and survive as the beat changes!

---

## Features
- **Real-time Audio Input** - Tired of listening to generic sample tracks? Circle Siege supports system audio capture, meaning you can use any of your media *(e.g. songs on Spotify)* as a level. Simply start the music playing and then select `System Audio`!
- **Simple Controls** - The only control you need to master, is your mouse. Focus on dodging obstacles, by simply moving your mouse around.
- **Visual and Audio feedback** - Dynamic visuals dance with the beat, creating a stunningly immersive gameplay environment.
- **Multiple Themes** - Always feel stuck with a generic neon-based theme? Choose from a set of varying colour themes to change up your screen!
- **Accessibility** - Circle Siege is built with accessibility needs in mind. Tone down or disable any/all background movement or select a high contrast/colourblind-friendly palette to suit your preferences.

---

## Gameplay
The objective of Circle Siege is to survive as long as possible, by dodging the incoming obstacles. You can select a difficulty at the start, which will inform the obstacle speed/density and how many lives you get (which can be viewed by the squares in the top-right corner).

Choose your favourite colour palette and customise Circle Siege to your liking via the in-game settings menu (found on the game start screen). You can also toggle background effects and adjust accessibility options here.

To start a game, select your preferred input source - select `System Audio` to play to your system audio (e.g. off Spotify), `File` to pick a local audio file, or `Demo` to use the included demo track (mixed by me!).

## Controls
The only control you have to manage is your mouse! Your sprite will follow the cursor, as your weave between projectiles. Use `Space`/`Enter` to select menu options.

---

## Installation
> [!IMPORTANT]
> **Windows Only**. (For now, due to audio loopback API compatability)
> Cross-platform compatibility may be added in the future.

1. Download the latest `.zip` archive release, [here](https://github.com/MadAvidCoder/Circle-Siege/releases/latest).
2. Extract the archive into a directory of your choice. *(All of the archive's contents **MUST** remain in the same directory)*.
3. Run `Circle Siege.exe`, and choose your game mode! *(Your system may warn you that the package is unsigned. You can safely bypass this warning, and can audit the code if you are concerned.)*

## Tech Stack
- **Godot Engine** (core game frontend, UI, scripting)
- **GDScript** (game logic)
- **Rust** (audio analysis/FFT, backend server, performance)
- **GDShader** (custom visual effects)
- **tokio** (backend async framework)
- **aubio** (tempo and beat detection)
- **clap** (backend CLI)

---

## License
Circle Siege is licensed under the [MIT License](LICENSE).

You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software. You must include the copyright and license notice.

**There is no warranty.** Circle Siege is provided “as is.”. Play, enjoy, and modify at your own risk.
