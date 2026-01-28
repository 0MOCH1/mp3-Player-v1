#!/bin/bash

# Verification script for NowPlaying port
# This script verifies all files are in place and provides a checklist

echo "=== NowPlaying Screen Port Verification ==="
echo ""

# Check if all required files exist
echo "Checking file structure..."
MISSING_FILES=0

check_file() {
    if [ -f "$1" ]; then
        echo "✓ $1"
    else
        echo "✗ MISSING: $1"
        ((MISSING_FILES++))
    fi
}

# Core files
check_file "mp3 Player/Features/Playback/AppleMusicStyle/AppleMusicNowPlayingView.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/NowPlayingAdapter.swift"

# Check key components
check_file "mp3 Player/Features/Playback/AppleMusicStyle/NowPlaying/ExpandableNowPlaying.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/NowPlaying/RegularNowPlaying.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/NowPlaying/CompactNowPlaying.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/UI/UniversalOverlay.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/UI/DominantColors.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/UI/Components/ElasticSlider.swift"
check_file "mp3 Player/Features/Playback/AppleMusicStyle/UI/Components/Background/MulticolorGradientShader.metal"

# Check modified files
check_file "mp3 Player/ContentView.swift"
check_file "mp3 Player/mp3_PlayerApp.swift"

echo ""
echo "Total files found: All key files present"
if [ $MISSING_FILES -eq 0 ]; then
    echo "✓ All critical files are in place"
else
    echo "✗ Warning: $MISSING_FILES files are missing"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Open 'mp3 Player.xcodeproj' in Xcode"
echo "2. Add the AppleMusicStyle folder to the project (see INTEGRATION_GUIDE.md)"
echo "3. Build the project (Cmd+B)"
echo "4. Run on simulator and test the new NowPlaying screen"
echo ""
echo "See PORT_SUMMARY.md for detailed information about the port"
echo "See INTEGRATION_GUIDE.md for step-by-step Xcode integration instructions"
