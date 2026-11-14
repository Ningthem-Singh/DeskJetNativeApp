# HP DeskJet Studio Pro for macOS (Apple Silicon M-Series)

A 100% native Apple Silicon (ARM64) macOS application for the **HP DeskJet 2600 All-in-One Series** (DeskJet Ink Advantage 2600 / Y5Z03B).

Built to replace bloated legacy Intel/Rosetta software and cloud-dependent tools like HP Smart. Works completely offline, natively, and with zero account requirements.

---

## 🖨️ Connected Device Profile

- **Model:** HP DeskJet 2600 All-in-One series (HP DeskJet Ink Advantage 2600 - Model `Y5Z03B`)
- **Serial Number:** `CN76Q2B02Z06PR`
- **Firmware:** `THP1FN2021BR`
- **Connection:** USB (Direct IPP-over-USB + AirScan eSCL Tunnel)
- **CUPS Queue Name:** `HP_DeskJet_2600_series` (Default system destination)
- **Ink Cartridges:**
  - **HP 680 Black:** ~20% remaining (Genuine HP, Good)
  - **HP 680 Tri-Color:** 0% remaining (Refilled / Needs refill)

---

## 🚀 Native macOS Built-in Features (Out of the Box)

Your printer is already recognized natively by macOS driverless architecture:

### 1. Printing
- **Everyday apps:** Press `Cmd + P` in Safari, Pages, Word, Chrome, Preview, or Mail. Select **HP DeskJet 2600 series**.
- **Terminal CLI:**
  ```bash
  lp document.pdf
  # or
  lpr -P HP_DeskJet_2600_series document.pdf
  ```

### 2. Scanning
You can scan natively without third-party drivers using any of:
- **Apple Image Capture:** Launch `/System/Applications/Image Capture.app`
- **System Settings:** Go to `System Settings` -> `Printers & Scanners` -> `HP DeskJet 2600 series` -> `Open Scanner`
- **Apple Preview:** Open `Preview.app` -> `File` -> `Import from Scanner` -> `HP DeskJet 2600 series...`

---

## 💻 Native M-Series App: "DeskJet Pro"

Located at:
- **Application:** `~/Applications/DeskJet Pro.app`
- **Project Source:** `/Users/ning-macmini/.gemini/antigravity/scratch/DeskJetNativeApp`

### Key Features:
1. **Live Dashboard & Health:**
   - Real-time printer status (Idle, Printing, Power Save).
   - Visual Ink Gauges for Black (HP 680) and Tri-Color (HP 680) cartridges.
   - Quick diagnostics: 1-click Test Page, Embedded Web Server (EWS) launcher, and macOS settings shortcut.
2. **Scan Studio:**
   - Native eSCL driverless communication with the flatbed platen.
   - Adjustable resolution: 75, 100, 200, 300 (Recommended), and 600 DPI.
   - Color Modes: Full Color (RGB), Grayscale (8-bit), and Black & White (Text).
   - Formats: JPEG and PDF.
   - Live preview canvas with Zoom, 90° Rotation, "Save As...", "Copy to Clipboard", and "Open in Preview".
3. **Direct Print Studio:**
   - Drag-and-drop zone for PDF, JPEG, PNG, TIFF, and Text files.
   - Select copies, paper size (A4, Letter, 4x6 Photo), color/monochrome, and draft/normal/photo quality.
   - One-click instant printing.
4. **Print Queue & Spooler:**
   - View pending print jobs in the CUPS queue.
   - Cancel individual jobs or clear the entire print spooler.

---

## 🛠️ Rebuilding / Modifying the App

To recompile with custom modifications:

```bash
cd /Users/ning-macmini/.gemini/antigravity/scratch/DeskJetNativeApp
./build_app.sh --install
```
