# Squishy

> **A fast, native macOS image resizer that never distorts your photos.**  
> Inspired by Microsoft PowerToys Image Resizer, re-engineered as a first-class Mac utility.

Created by **[Silverstone Labs](https://apps.silverstonelabs.in)**  
- **Website**: [apps.silverstonelabs.in](https://apps.silverstonelabs.in)  
- **Support**: [info@silverstonelabs.in](mailto:info@silverstonelabs.in)  

---

## Highlights

- **Strict Aspect-Ratio Preservation**: Never stretches, squashes, or distorts images. Every resize operation mathematically fits within bounding constraints while maintaining exact proportions.
- **Accidental Upscaling Prevention**: Small images remain sharp and untouched by default unless upscaling is explicitly enabled.
- **Social Media & Common Aspect Ratio Presets**: Quick-select popular aspect ratios (1:1 Square, 4:5 Portrait, 9:16 Story/Reels, 16:9 Landscape, 1.91:1 Feed, 4:3 Standard, 3:2 Photography) with 1-click inversion ($3:4 \leftrightarrow 4:3$) and dimension swapping ($W \leftrightarrow H$).
- **Synchronized Mode Tabs**: Switching between *Preset*, *Fit*, *Width*, *Height*, and *Percentage* preserves proportional dimensions automatically.
- **Hardware-Accelerated Downsampling**: Powered by Apple Core Graphics and Image I/O (`CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`) for low-memory, high-speed batch decoding.
- **Color Profiles & Transparency**: Full alpha channel support for PNG, TIFF, and WebP, preserving original color spaces and EXIF orientations.
- **Date & Metadata Preservation**: Optionally retains original file creation and modification timestamps (`preserveFileTimestamps`), alongside camera EXIF tags.
- **Automatic In-App Updates**: Integrated with **Sparkle 2**, featuring background checks, cryptographic Ed25519 signature validation, and a native SwiftUI Settings panel (`⌘,`).
- **Flexible Native macOS UI**: Built with modern SwiftUI and AppKit using an interactive split-view layout (`HSplitView`), live output badge preview, Finder drag-and-drop, and keyboard shortcuts (`⌘O`, `⌘R`, `⌘K`).
- **Universal 2 Binary**: Natively compiled for both **Apple Silicon** (`arm64`) and **Intel** (`x86_64`) Macs.

---

## Core Resizing Engine

For an original image with width $W$ and height $H$, and maximum target bounds $TW$ and $TH$:

$$\text{scale} = \min\left(\frac{TW}{W}, \frac{TH}{H}\right)$$

When **upscaling is disabled** (the default behavior):

$$\text{scale} = \min(1.0, \text{scale})$$

The final integer pixel dimensions are calculated using the identical scale factor:

$$\text{Output Width} = \max\left(1, \operatorname{round}(W \times \text{scale})\right)$$
$$\text{Output Height} = \max\left(1, \operatorname{round}(H \times \text{scale})\right)$$

### Example
A $4000 \times 3000$ (4:3) image resized against the **Medium** preset ($1366 \times 768$) computes to **$1024 \times 768$**, perfectly fitting within the bounding box without cropping or horizontal stretching.

---

## Resizing Modes

1. **Preset**: Bounding boxes inspired by PowerToys (*Small: 854×480*, *Medium: 1366×768*, *Large: 1920×1080*, *4K: 3840×2160*, *Mobile: 1080×1920*), plus customizable user presets.
2. **Fit Within Bounds**: User-defined maximum width and maximum height limits with an orientation swap button (`⇄`).
3. **Width Only**: Specify target width; height calculates automatically based on the original aspect ratio.
4. **Height Only**: Specify target height; width calculates automatically based on the original aspect ratio.
5. **Percentage**: Scale relative to original dimensions (25%, 50%, 75%, 150%, 200%, or custom percent).

---

## Project Structure

```
Squishy/
├── project.yml                     # XcodeGen project definition & Sparkle SPM dependency
├── ImageResizer.xcodeproj          # Native Xcode project
├── build.sh                        # Automated build & packaging script
├── ImageResizer/
│   ├── App/
│   │   ├── ImageResizerApp.swift   # Main SwiftUI App entry, macOS menus & commands
│   │   └── AppSettings.swift       # Persistent user settings & configuration
│   ├── Models/
│   │   ├── ResizeMode.swift        # Enum of resizing strategies
│   │   ├── ResizePreset.swift      # Built-in & user-defined presets
│   │   ├── AspectRatioPreset.swift # Social media & photo aspect ratio templates
│   │   ├── OutputFormat.swift      # JPEG, PNG, HEIC, TIFF, WebP format handlers
│   │   ├── ImageDimensions.swift   # Dimension calculations & aspect ratio math
│   │   ├── ImageItem.swift         # Queue item with thumbnail, metadata & status
│   │   ├── ResizeConfiguration.swift # Active resizing options & timestamp toggle
│   │   └── BatchResizeResult.swift # Batch execution metrics & error logs
│   ├── Services/
│   │   ├── ImageResizeEngine.swift # Non-distorting mathematical engine & Image I/O pipeline
│   │   ├── ImageFileService.swift  # Open panels, drag-and-drop parsing & thumbnails
│   │   ├── BatchResizeService.swift# Concurrency-limited background processing
│   │   ├── OutputManager.swift     # File path resolution, collision handling & dates
│   │   ├── PresetStore.swift       # Preset persistence & CRUD
│   │   └── UpdateManager.swift     # Sparkle 2 updater controller & delegate
│   ├── Views/
│   │   ├── MainView.swift          # Primary window layout & drag-and-drop handling
│   │   ├── EmptyDropZoneView.swift # Welcome drop area & branding
│   │   ├── ImageQueueView.swift    # Selected files list with live dimension display
│   │   ├── ImageRowView.swift      # File card with thumbnail, dimensions & removal
│   │   ├── ResizeSettingsView.swift# Flexible control pane with aspect ratio pills
│   │   ├── PresetManagerSheet.swift# Preset editor dialog
│   │   ├── UpdateSettingsView.swift# App preferences & Sparkle update controls
│   │   ├── BatchProgressView.swift # Non-blocking progress indicator with cancel
│   │   ├── ResizeResultsView.swift # Completion card with "Reveal in Finder"
│   │   └── Components/
│   │       ├── AspectRatioLockIndicator.swift
│   │       ├── CardContainer.swift
│   │       └── DropOverlayView.swift
│   ├── Entitlements/
│   │   └── ImageResizer.entitlements # Outgoing network & user file access
│   └── Resources/
│       ├── Info.plist              # Bundle metadata, Sparkle keys & Silverstone info
│       └── Assets.xcassets/
│           └── AppIcon.appiconset/ # Native macOS squircle app icons (16px to 1024px)
└── ImageResizerTests/
    ├── ImageResizeEngineTests.swift # 21 tests for math, clamping, rounding & sync
    ├── OutputManagerTests.swift     # 5 tests for file collisions & naming
    ├── PresetStoreTests.swift       # 3 tests for preset CRUD & persistence
    ├── ImageProcessingTests.swift   # 8 tests for format conversion & metadata
    ├── AspectRatioPresetTests.swift # 3 tests for aspect ratio math & inversion
    └── UpdateManagerTests.swift     # 3 tests for Sparkle integration & branding
```

---

## Build and Run

### System Requirements
- macOS 14.0 Sonoma or later
- Xcode 15.0 or later (Xcode 16+ recommended)

### Build Script (`build.sh`)
An automated build script is included to produce debug, release, or universal application bundles:

```bash
# Build Universal 2 binary (Apple Silicon arm64 + Intel x86_64)
./build.sh universal

# Build standard Release .app bundle
./build.sh release

# Build Debug .app bundle
./build.sh debug

# Build and launch the application immediately
./build.sh universal --open

# Build all configurations (Debug, Release, Universal)
./build.sh all

# Run complete automated test suite (43 unit tests)
./build.sh test

# Clean build artifacts
./build.sh clean
```

Compiled application bundles are placed in:
- `build/Release-Universal/Squishy.app` (Universal: `arm64` + `x86_64`)
- `build/Release/Squishy.app` (Native host architecture)
- `build/Debug/Squishy.app`

### Open in Xcode
Open `ImageResizer.xcodeproj` in Xcode and press **⌘R** to run, or **⌘U** to run unit tests.

### Command-Line Build & Test
```bash
# Build with xcodebuild
xcodebuild -project ImageResizer.xcodeproj -scheme ImageResizer -configuration Release build

# Run unit tests
xcodebuild -project ImageResizer.xcodeproj -scheme ImageResizerTests test
```

### Regenerate Xcode Project (Optional)
If you update `project.yml`, regenerate the `.xcodeproj` anytime using [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```bash
xcodegen generate
```

---

## Software Updates (Sparkle 2)

Squishy uses [Sparkle 2](https://github.com/sparkle-project/Sparkle) for seamless, secure background updates:

- **Feed URL**: Configured via `SUFeedURL` in `Info.plist`.
- **Cryptographic Signatures**: Verified against `SUPublicEDKey` using Ed25519 signatures.
- **Generating Update Keys**:
  ```bash
  # Locate Sparkle's key generator tool from the SPM build artifacts
  build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
  ```
- **Menu Bar & Settings**: Updates can be checked manually via **Squishy > Check for Updates…** or inside **Settings > Automatic Updates**.

---

## About & Support

**Squishy** is developed and maintained by **Silverstone Labs**.

- **Website**: [apps.silverstonelabs.in](https://apps.silverstonelabs.in)
- **Support & Inquiries**: [info@silverstonelabs.in](mailto:info@silverstonelabs.in)
- **Copyright**: © 2026 Silverstone Labs. All rights reserved.
