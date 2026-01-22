#!/bin/bash
# Build check script for LogChat

cd "$(dirname "$0")"

echo "🔍 Checking LogChat project for errors..."
echo ""

# Try xcodebuild
if command -v xcodebuild &> /dev/null; then
    echo "Using xcodebuild..."
    xcodebuild -project LogChat.xcodeproj \
               -scheme LogChat \
               -sdk iphonesimulator \
               -destination 'platform=iOS Simulator,name=iPhone 15' \
               clean build 2>&1 | \
    tee /tmp/logchat_build.log | \
    grep -E "error:|warning:|❌|✅|BUILD SUCCEEDED|BUILD FAILED" | \
    head -100
    
    BUILD_RESULT=$?
    if [ $BUILD_RESULT -eq 0 ]; then
        echo ""
        echo "✅ Build completed. Checking for errors..."
        if grep -q "error:" /tmp/logchat_build.log; then
            echo "❌ Errors found:"
            grep "error:" /tmp/logchat_build.log | head -20
            exit 1
        else
            echo "✅ No errors found!"
            exit 0
        fi
    else
        echo "❌ Build failed"
        exit 1
    fi
else
    echo "xcodebuild not found. Skipping build check."
    exit 0
fi
