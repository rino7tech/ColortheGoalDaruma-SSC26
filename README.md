# Daruma — Goal Setting App
**Swift Student Challenge 2026**

An iPad app that uses the traditional Japanese **Daruma doll** as a cultural medium to support the journey from goal setting to action.

---

## Features

**Daruma Color Diagnosis**  
A chat-based interface breaks goals down step by step. A 3D Daruma rendered in SceneKit changes color in real time as the diagnosis unfolds.

**Eye Painting**  
A custom brush shader built with Metal reproduces ink diffusion and pressure sensitivity, recreating the feeling of painting a Daruma's eye with a real brush.

**Wish Writing & OCR**  
Users can write a wish directly on the back of the Daruma. The text is recognized via Vision's `VNRecognizeTextRequest` to determine the matching color.

---

## Tech Stack

| | |
|---|---|
| SwiftUI | UI & state management |
| SceneKit | 3D model rendering & animation |
| Metal | Custom brush shader |
| Vision | Handwriting recognition |

---

## Requirements

- iPadOS 17.0+
- Xcode 15.0+
- Apple Pencil (recommended)

---

## Credits

| Asset | Creator | Source |
|---|---|---|
| Daruma 3D Model | 3D Ara-monoya | BOOTH |
| Shooting-star Effect | solisnotte (hanamori design) | BOOTH |
| Tatami & Wood Textures | — | Illustration AC |
