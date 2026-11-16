cask "squishy" do
  version "1.0.23"
  sha256 "b8ad0981f4323e53ae2385f30ab46c1c08d912b48703d3f595524217c95d2ccc"

  url "https://github.com/bhooshanb/squishy-macos-app/releases/download/release/Squishy.zip"
  name "Squishy"
  desc "Native macOS image resizer that preserves aspect ratio"
  homepage "https://apps.silverstonelabs.in"

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
