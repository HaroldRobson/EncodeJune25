#!/bin/bash

# Video Upload API Testing
# Run: docker compose up -d

echo "🎥 Testing Video Upload API"
echo "==========================="

BASE_URL="http://localhost:8080"

# Create a test video file (small dummy file for testing)
echo "Creating test video file..."
echo "This is a fake video file for testing" > test_video.mp4

# 1. Valid video upload
echo "1. Valid Video Upload..."
curl -s -X POST "$BASE_URL/api/uploads/video" \
  -F "video=@test_video.mp4" | jq .
echo -e "\n"

# 2. No file provided
echo "2. No File Provided..."
curl -s -X POST "$BASE_URL/api/uploads/video" | jq .
echo -e "\n"

# 3. Invalid file type (create a txt file)
echo "Creating invalid file type..."
echo "This is not a video" > test_document.txt
echo "3. Invalid File Type..."
curl -s -X POST "$BASE_URL/api/uploads/video" \
  -F "video=@test_document.txt" | jq .
echo -e "\n"

# 4. Test video serving (first upload a video and get its URL)
echo "4. Testing Video Serving..."
UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/uploads/video" -F "video=@test_video.mp4")
VIDEO_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.video_url')

if [ "$VIDEO_URL" != "null" ] && [ "$VIDEO_URL" != "" ]; then
    echo "Trying to serve video at: $VIDEO_URL"
    curl -s -I "$VIDEO_URL" | head -n 5
else
    echo "Failed to get video URL from upload"
fi
echo -e "\n"

# 5. Test serving non-existent video
echo "5. Non-existent Video..."
curl -s "$BASE_URL/videos/nonexistent.mp4" | jq .
echo -e "\n"

# 6. Test path traversal attack (security test)
echo "6. Path Traversal Attack (should fail)..."
curl -s "$BASE_URL/videos/../../../etc/passwd"
echo -e "\n"

# Cleanup test files
echo "Cleaning up test files..."
rm -f test_video.mp4 test_document.txt

echo "✅ Testing Complete!"
echo "Check uploaded videos with:"
echo "docker exec -it donations_api ls -la /var/uploads/videos/"
