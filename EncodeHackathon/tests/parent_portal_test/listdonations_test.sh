#!/bin/bash

# List Donations API Testing
# Run: docker compose up -d

echo "📝 Testing List Donations API"
echo "=============================="

BASE_URL="http://localhost:8080"

# First, add some test donations for review
echo "Setting up test donations..."
docker exec -it donations_db psql -U postgres -d donations -c "
-- Add some test donations with mix of approved/pending
INSERT INTO donations (message, donor_name, amount_pence, approved, event_id, video_address) VALUES
('Happy birthday Emma! You'\''re amazing!', 'Uncle Bob', 500, true, 1, NULL),
('Hope you have the best day ever!', 'Aunt Sarah', 1000, false, 1, 'http://localhost:8080/videos/sarah_video.mp4'),
('From your biggest fan!', 'Cousin Mike', 250, false, 1, NULL),
('So proud of you sweetie!', 'Grandma Rose', 2000, true, 1, NULL),
('This message needs review...', 'Stranger Danger', 100, false, 1, NULL);
"

echo -e "\n"

# 1. Valid request (event_id = 1)
echo "1. Valid Request (Event ID: 1)..."
curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"event_id": 1}' | jq .
echo -e "\n"

# 2. Non-existent event
echo "2. Non-existent Event (ID: 999)..."
curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"event_id": 999}' | jq .
echo -e "\n"

# 3. Missing event_id
echo "3. Missing event_id..."
curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"wrong_field": 123}' | jq .
echo -e "\n"

# 4. Invalid JSON
echo "4. Invalid JSON..."
curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}' | jq .
echo -e "\n"

# 5. Event with no donations
echo "5. Creating event with no donations..."
# First create a new event
NEW_EVENT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Empty Event Test",
    "expires_at": "2025-12-31"
  }')

NEW_EVENT_ID=$(echo "$NEW_EVENT_RESPONSE" | jq -r '.event_id')

echo "6. Query event with no donations (ID: $NEW_EVENT_ID)..."
curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"event_id": '$NEW_EVENT_ID'}' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check statistics: total_donations, approved_donations, pending_donations"
echo "Verify donations are ordered by created_at DESC (newest first)"
