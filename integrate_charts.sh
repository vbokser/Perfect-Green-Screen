#!/bin/bash

# Copy DGCharts.xcframework to our project
mkdir -p "Perfect Green Screen/Frameworks"
cp -R Carthage/Build/DGCharts.xcframework "Perfect Green Screen/Frameworks/"

echo "DGCharts.xcframework has been copied to Perfect Green Screen/Frameworks/"
echo ""
echo "Now, in Xcode:"
echo "1. Add the xcframework to the project by dragging from Finder"
echo "2. In your Xcode project, select the target, go to 'General' tab"
echo "3. Under 'Frameworks, Libraries, and Embedded Content', click the '+' button"
echo "4. Click 'Add Other...' and navigate to 'Perfect Green Screen/Frameworks/DGCharts.xcframework'"
echo "5. Make sure 'Embed & Sign' is selected"
echo ""
echo "This should resolve the 'No such module 'DGCharts'' error" 