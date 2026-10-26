# Image Resizer for macOS

A native macOS application inspired by **Microsoft PowerToys Image Resizer**, built from the ground up with Swift, SwiftUI, Core Graphics, and Image I/O.

---

## Highlights

- **Strict Aspect-Ratio Preservation**: Never stretches, squashes, or distorts images. All dimensions are calculated mathematically to fit inside bounding constraints.
- **Accidental Upscaling Prevention**: Small images remain crisp and untouched by default unless explicitly allowed.
- **PowerToys Presets & Custom Presets**: Predefined bounding boxes (Small, Medium, Large, Extra Large 4K, Mobile Portrait) plus the ability to add, edit, reorder, and persist custom presets.
- **Batch Processing with Concurrency Control**: Process hundreds of images simultaneously without memory pressure or UI freezing.
- **Hardware-Accelerated Downsampling**: Uses Apple's `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize` for fast, memory-efficient decoding.
- **Full EXIF Orientation & Metadata Preservation**: Automatically applies correct rotation for camera photos while preserving metadata tags and color profiles.
- **Transparency Support**: Alpha channels are preserved for PNG, TIFF, and WebP.
- **Safe File Management**: Default output is written to a dedicated `Resized/` subfolder with automatic duplicate numbering (`photo-resized (1).jpg`), ensuring your original files are never overwritten.
- **Native macOS Experience**: Designed to adhere strictly to Apple's Human Interface Guidelines (HIG) with full Dark Mode, drag-and-drop, AppKit open dialogs, and keyboard shortcuts (`⌘O`, `⌘R`, `⌘K`).

---

## Core Resizing Engine

For an original image with width $W$ and height $H$, and maximum target bounds $TW$ and $TH$:

$$\text{scale} = \min\left(\frac{TW}{W}, \frac{TH}{H}\right)$$

If **upscaling is disabled** (the default):

$$\text{scale} = \min(1.0, \text{scale})$$

The final output dimensions are:

$$\text{Output Width} = \max\left(1, \operatorname{round}(W \times \text{scale})\right)$$
$$\text{Output Height} = \max\left(1, \operatorname{round}(H \times \text{scale})\right)$$

### Example
A $4000 \times 3000$ image resized to the **Medium** preset ($1366 \times 768$) becomes **$1024 \times 768$** (preserving the 4:3 aspect ratio), never forcing $1366 \times 768$.

---

## Resizing Modes

1. **Preset**: Fit inside predefined standard bounding boxes (Small, Medium, Large, Extra Large 4K, Mobile).
2. **Fit Within Bounds**: User-defined maximum width and maximum height limits.
3. **Width Only**: Specify target width; height is derived automatically from the aspect ratio.
4. **Height Only**: Specify target height; width is derived automatically from the aspect ratio.
5. **Percentage**: Scale relative to original dimensions (25%, 50%, 75%, 150%, 200%, or custom percent).

---

## Project Structure

```
ImageResizer/
├── project.yml                     # XcodeGen project specification
├── ImageResizer.xcodeproj          # Native Xcode project
├── ImageResizer/
│   ├── App/
│   │   ├── ImageResizerApp.swift   # Main app entry point & macOS menus
│   │   └── AppSettings.swift       # Persistent user preferences
│   ├── Models/
│   │   ├── ResizeMode.swift        # Enum of resizing strategies
│   │   ├── ResizePreset.swift      # PowerToys presets & custom preset model
│   │   ├── OutputFormat.swift      # Supported output formats (JPEG, PNG, HEIC, TIFF, WebP)
│   │   ├── ImageDimensions.swift   # Dimension calculations & aspect ratio helpers
│   │   ├── ImageItem.swift         # Queue item with thumbnail, metadata & status
│   │   ├── ResizeConfiguration.swift # Active resizing options
│   │   └── BatchResizeResult.swift # Result metrics & error tracking
│   ├── Services/
│   │   ├── ImageResizeEngine.swift # Core mathematical calculation & Image I/O processing
│   │   ├── ImageFileService.swift  # File picker, drag-and-drop & metadata parsing
│   │   ├── BatchResizeService.swift# Concurrency-limited background task pipeline
│   │   ├── OutputManager.swift     # Destination path resolution & collision safety
│   │   └── PresetStore.swift       # Built-in and user preset storage
│   ├── Views/
│   │   ├── MainView.swift          # Primary window layout & drag-and-drop
│   │   ├── EmptyDropZoneView.swift # Welcome empty state
│   │   ├── ImageQueueView.swift    # Selected files list with live dimension display
│   │   ├── ImageRowView.swift      # Individual file card with status & quick delete
│   │   ├── ResizeSettingsView.swift# Control pane (mode, dimensions, format, destination)
│   │   ├── PresetManagerSheet.swift# Preset editor dialog
│   │   ├── BatchProgressView.swift # Non-blocking progress indicator with cancel
│   │   ├── ResizeResultsView.swift # Completion card with "Reveal in Finder"
│   │   └── Components/
│   │       ├── AspectRatioLockIndicator.swift
│   │       ├── CardContainer.swift
│   │       └── DropOverlayView.swift
│   └── Resources/
│       ├── Info.plist
│       └── Assets.xcassets/
└── ImageResizerTests/
    ├── ImageResizeEngineTests.swift # 17 tests for math, rounding & modes
    ├── OutputManagerTests.swift     # 5 tests for file collisions & naming
    ├── PresetStoreTests.swift       # 3 tests for preset persistence & CRUD
    └── ImageProcessingTests.swift   # 6 tests for actual image encoding & decoding
```

---

## Build and Run

### Requirements
- macOS 14.0 Sonoma or later
- Xcode 15 or later (Xcode 16+ recommended)

### Build Script (`build.sh`)
An executable build script is provided to automate compilation, testing, and Universal packaging:

```bash
# Build Universal 2 binary for both Apple Silicon (arm64) & Intel (x86_64)
./build.sh universal
# or:
./build.sh release --universal

# Build standard Release .app bundle
./build.sh
# or
./build.sh release

# Build Debug .app bundle
./build.sh debug

# Build and launch immediately
./build.sh universal --open

# Build Debug, Release, and Universal bundles
./build.sh all

# Run unit tests
./build.sh test

# Clean build artifacts
./build.sh clean
```

The resulting applications are placed in:
- `build/Release-Universal/ImageResizer.app` (Apple Silicon `arm64` + Intel `x86_64`)
- `build/Release/ImageResizer.app`
- `build/Debug/ImageResizer.app`

### Open with Xcode
Open `ImageResizer.xcodeproj` in Xcode and press **⌘R** to run.

### Build via Command Line
```bash
xcodebuild -project ImageResizer.xcodeproj -scheme ImageResizer build
```

### Run Unit Tests
```bash
./build.sh test
# or:
xcodebuild -project ImageResizer.xcodeproj -scheme ImageResizerTests test
```
All unit tests will execute and verify dimension calculations, aspect ratios, image formats, collision safety, and preset handling.

### Regenerate Xcode Project (Optional)
If you modify `project.yml`, regenerate the project anytime:
```bash
xcodegen generate
```
