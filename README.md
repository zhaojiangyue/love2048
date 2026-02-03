# NVIDIA 2048: Neural Edition

A high-tech, hardware-themed spin on the classic 2048 puzzle game. Manage heat, train neural networks, and upgrade your GPU from a GT 210 all the way to Jensen's Kitchen.

![Version](https://img.shields.io/badge/version-1.0-green)
![Engine](https://img.shields.io/badge/love2d-11.5-pink)

## 🎮 How to Play

**Goal:** Merge identical GPUs to upgrade them. Reach **2048 (Jensen's Kitchen)** to win, but don't stop there!

### Controls
- **Arrow Keys**: Move tiles (Up, Down, Left, Right).
- **Space**: Use **DLSS** to upscale (upgrade) a selected tile.
- **Esc**: Pause / Unpause.
- **Ctrl+R**: Restart game.
- **M**: Toggle Mute.

---

## ⚡ Key Mechanics

This isn't just standard 2048. You must manage your system's resources:

### 1. 🔥 Heat & Throttling
*   **Heat Generation:** High-tier cards (RTX 4090, H100) generate heat when merged.
*   **Throttling:** If heat reaches **100%**, your system throttles! Random high-tier tiles will be **downgraded**.
*   **Cooling:** Make moves without generating heat to cool down the system.

### 2. 🧠 Neural Training
*   **Training:** Keep a tile alive for **10 moves** to "Train" it (Cyan glow).
*   **Bonus:** Merging trained tiles yields **2x Score**.
*   **Overtraining:** Don't wait too long! If a tile survives **30 moves** without merging, it becomes **Overtrained** (Red Pulse). You have 12 moves to merge it, or the neural network collapses (Game Over).

### 3. ✨ DLSS Upscaling (Active Ability)
*   **Charges:** You start with 3 DLSS charges. Regenerate them by scoring points.
*   **Action:** Press `SPACE` to enter selection mode. Pick a tile to instantly **double its value**.
*   **Strategy:** Use this to save an overtrained tile or complete a massive merge chain.

### 4. 🔗 SLI / NVLink Bridges
*   **Formation:** Place identical tiles adjacent to each other.
*   **Bonus:** Merging tiles in an SLI formation grants massive score multipliers (up to **10x** for a 4-tile bridge!).

### 5. 🌊 Tensor Cascades
*   **Effect:** Merging RTX-tier cards triggers a "Tensor Cascade", randomly boosting an adjacent tile's value.

---

## 🛠️ Installation & Running

1.  Install [LÖVE](https://love2d.org/) (Version 11.5 recommended).
2.  Clone this repository.
3.  Drag the project folder onto `love.exe` or run:
    ```bash
    love .
    ```

## 📂 Project Structure

*   `main.lua`: Entry point and game loop.
*   `src/game_state.lua`: Centralized state management.
*   `src/mechanics.lua`: Logic for Heat, Training, DLSS, and SLI.
*   `src/ui/renderer.lua`: Visuals, particles, and animations.
*   `src/constants.lua`: Game configuration and tuning.

## 👨‍💻 Credits

*   **Engine:** LÖVE 2d
*   **Theme:** NVIDIA Hardware History
*   **Vibe:** Maximum