#!/bin/bash

# Clean up any existing Charts directory
rm -rf DGCharts

# Clone DGCharts from the r-n-i fork
git clone https://github.com/r-n-i/DGCharts.git

# Move into the directory
cd DGCharts

# Make the xcframework
xcodebuild -project Charts.xcodeproj -scheme "DGCharts" -destination generic/platform=iOS -configuration Release ONLY_ACTIVE_ARCH=NO ARCHS="arm64" BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -derivedDataPath build clean build

# Create a directory for the finished product
mkdir -p ../Perfect\ Green\ Screen/Frameworks

# Copy the framework to our project
cp -R build/Build/Products/Release-iphoneos/DGCharts.framework ../Perfect\ Green\ Screen/Frameworks/

echo "DGCharts.framework has been copied to Perfect Green Screen/Frameworks/"
echo "Now, in Xcode:"
echo "1. Add the framework to the project (drag and drop from Finder)"
echo "2. Make sure it's added to the target"
echo "3. In Build Phases, add a 'Copy Files' phase if needed"
echo "4. Add DGCharts.framework to this phase, with destination 'Frameworks'" 