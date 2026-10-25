# README

## Build and run in Xcode

Open `Perfect Green Screen.xcodeproj` and select the shared **Perfect Green Screen** scheme.
The app supports iOS 17.6 and later. Xcode resolves **DGCharts 5.1.0** from the official
[ChartsOrg/Charts repository](https://github.com/ChartsOrg/Charts) with Swift Package Manager.
The resolved version is recorded at
`Perfect Green Screen.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
Carthage and downloaded frameworks are no longer needed. This is an Xcode app target,
so there is no root `Package.swift` to open as a separate library.

Choose your paired iPhone or iPad as the run destination, build, and allow camera access
when prompted. Automatic signing is configured for the existing development team.
A simulator can verify launch and interface behavior; a physical device is required
for the live camera, banded image, histogram, and focus/exposure locks.

The app uses a storyboard-backed `UIWindowScene` lifecycle for current iOS SDKs.
The live preview uses its pane's backing layer, so switching between **Band View**
and **Both Views** keeps the camera image inside its pane.

## Version, build number, and timestamp

The app version is **2.0**. The app target's **Generate Build Metadata** phase runs
`scripts/generate-build-metadata.py` on every build, including incremental builds
from Xcode or `xcodebuild`, for Debug, Release, simulator, device, and archive builds.
It advances the shared counter in `BuildSupport/BuildNumber.txt`; keep this file
when committing changes or moving the project. Clean and deleting DerivedData do
not reset it. Concurrent builds reserve separate numbers using a file lock.

The script generates `BuildMetadata.h` in Xcode's derived-files directory. Xcode
preprocesses the app's Info.plist with that header, so the finished, signed app
contains the new build number and a UTC build timestamp in `PGSBuildTimestamp`.
`CURRENT_PROJECT_VERSION` is a minimum for the counter, rather than the finished
app's generated number. Each build attempt consumes a number, even if a later
build step fails. No separate manual script invocation is needed.

The bottom of the in-app Info page displays the version, generated build number,
and build timestamp in the device's local time, including its time zone.

Run the script checks with `/usr/bin/python3 -m unittest discover -s scripts`.

## Regression tests

Use **Product → Test** in Xcode. The `Perfect Green ScreenTests` target covers scene
configuration, storyboard and chart loading, camera preview setup without a connected
camera, repeated pane switching, persisted band settings, banding, and sampled
histogram percentages. Run these tests in an iOS simulator. They preserve and restore
the band settings they modify.

# Intro: 
Perfect Green Screen takes an image in of your lit green screen and 
gives you a band view of the green screen showing all the gradation in the image (based on how graduated you want to see 
the image)

# Why is this important?

Well, its sort of like a zebra setting for every block of image range in your image.
Or a False color even (even though its all grey)

So for example if you set it to 10 bands - each band is approx a range 32 values in the gradation for each band.

The purpose when lighting a green screen is to keep the gradation to a minimum - to make it even as possible - 
thus have less gradation changes.

So if you see too many bands in your green screen, you know you need to have better lighting to make your key better.

Its a small but useful tool. One of many you should use.

# How does it work:

Two images are displayed
Left Image: Original Color Image
Right Image: Gradation Grey Scale Image

Bands: usually 10 or so is a good start to get good key.. with 1-2 bands for the green screen range



