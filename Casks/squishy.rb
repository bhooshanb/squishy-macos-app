cask "squishy" do
  version "1.0.25"
  sha256 "726ae1ec9a76821f319be1a3bbdb5a0eb969b5cc4302a732179d63b59a9eab2e"

  url "https://github.com/bhooshanb/squishy-macos-app/releases/download/release/Squishy.zip"
  name "Squishy"
  desc "Native macOS image resizer that preserves aspect ratio"
  homepage "https://squishy.silverstonelabs.in/"

  depends_on macos: ">= :sonoma"

  app "Squishy.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", appdir/"Squishy.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.silverstonelabs.ImageResizer.plist",
    "~/Library/Application Support/com.silverstonelabs.ImageResizer",
  ]
end
