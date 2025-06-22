#!/bin/bash

# Get Video API Testing
# Run: docker compose up -d

echo "🎬 Testing Get Video API"
echo "========================"

BASE_URL="http://localhost:8080"

# Setup: Upload a test video first to have something to retrieve
echo "🔧 Setting up test video..."
echo "fake video content for testing getvideo endpoint" > /tmp/test_video_getvideo.mp4

UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/uploads/video" \
  -F "video=@/tmp/test_video_getvideo.mp4")

echo "Upload response: $UPLOAD_RESPONSE"
VIDEO_URL=$(echo $UPLOAD_RESPONSE | jq -r '.video_url')
FILENAME=$(basename "$VIDEO_URL")
echo "📹 Test video filename: $FILENAME"
echo ""

# Clean up temp file
rm /tmp/test_video_getvideo.mp4

# 1. Valid video retrieval
echo "1. Valid Video Retrieval..."
curl -s -I "$BASE_URL/api/videos/$FILENAME" | head -5
echo ""

# 2. Download video content
echo "2. Download Video Content..."
CONTENT=$(curl -s "$BASE_URL/api/videos/$FILENAME")
echo "Content preview: ${CONTENT:0:50}..."
echo "Content length: ${#CONTENT} characters"
echo ""

# 3. Non-existent video
echo "3. Non-existent Video..."
curl -s "$BASE_URL/api/videos/nonexistent_video.mp4" | jq .
echo ""

# 4. Invalid filename with path traversal
echo "4. Path Traversal Attack..."
curl -s "$BASE_URL/api/videos/../../../etc/passwd" | jq .
echo ""

# 5. Invalid filename with backslashes
echo "5. Backslash Path Attack..."
curl -s "$BASE_URL/api/videos/..\\..\\windows\\system32\\config" | jq .
echo ""

# 6. Invalid file extension
echo "6. Invalid File Extension..."
curl -s "$BASE_URL/api/videos/malicious_file.txt" | jq .
echo ""

# 7. Empty filename
echo "7. Empty Filename..."
curl -s "$BASE_URL/api/videos/" | jq .
echo ""

# 8. Test video seeking (range requests)
echo "8. Test Range Request (Video Seeking)..."
curl -s -H "Range: bytes=0-100" -I "$BASE_URL/api/videos/$FILENAME" | grep -E "(HTTP|Content-Range|Accept-Ranges)"
echo ""

# 9. Check cache headers
echo "9. Check Cache Headers..."
curl -s -I "$BASE_URL/api/videos/$FILENAME" | grep -E "(Cache-Control|Content-Type)"
echo ""

# 10. Test with different video extensions
echo "10. Upload and Test Different Extensions..."

# Upload .mov file
echo "fake mov content" > /tmp/test.mov
MOV_UPLOAD=$(curl -s -X POST "$BASE_URL/api/uploads/video" -F "video=@/tmp/test.mov")
MOV_URL=$(echo $MOV_UPLOAD | jq -r '.video_url')
MOV_FILENAME=$(basename "$MOV_URL")
echo "MOV upload: $MOV_URL"
curl -s -I "$BASE_URL/api/videos/$MOV_FILENAME" | head -3
rm /tmp/test.mov
echo ""

# Upload .webm file  
echo "fake webm content" > /tmp/test.webm
WEBM_UPLOAD=$(curl -s -X POST "$BASE_URL/api/uploads/video" -F "video=@/tmp/test.webm")
WEBM_URL=$(echo $WEBM_UPLOAD | jq -r '.video_url')
WEBM_FILENAME=$(basename "$WEBM_URL")
echo "WEBM upload: $WEBM_URL"
curl -s -I "$BASE_URL/api/videos/$WEBM_FILENAME" | head -3
rm /tmp/test.webm
echo ""

echo "✅ Testing Complete!"
echo ""
echo "🔍 Check uploaded videos:"
echo "docker exec donations_api ls -la /var/uploads/videos/"
echo ""
echo "📺 Test in browser:"
echo "Open: $VIDEO_URL"
echo "Should play/download the test video file"
echo ""
echo "🎬 Frontend Integration:"
echo "<video controls>"
echo "  <source src=\"$VIDEO_URL\" type=\"video/mp4\">"
echo "</video>"
