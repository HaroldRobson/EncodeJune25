#!/bin/bash

# Create Event API Testing
# Run: docker compose up -d

echo "🎂 Testing Create Event API"
echo "============================"

BASE_URL="http://localhost:8080"

# 1. Valid event creation
echo "1. Valid Event Creation..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Emma'\''s 9th Birthday Party",
    "expires_at": "2026-07-15",
    "event_message": "Emma is turning 9! Let'\''s make it the best birthday ever!",
    "videos_enabled": true,
    "photo_address": "https://example.com/emma-9th.jpg"
  }' | jq .
echo -e "\n"

# 2. Another valid event (minimal fields)
echo "2. Minimal Valid Event..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Emma'\''s Christmas Fund 2025",
    "expires_at": "2025-12-20"
  }' | jq .
echo -e "\n"

# 3. Missing required fields
echo "3. Missing Required Fields..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Missing Date Event"
  }' | jq .
echo -e "\n"

# 4. Invalid date format
echo "4. Invalid Date Format..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Bad Date Event",
    "expires_at": "15-07-2025"
  }' | jq .
echo -e "\n"

# 5. Past expiry date
echo "5. Past Expiry Date..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Past Event",
    "expires_at": "2020-01-01"
  }' | jq .
echo -e "\n"

# 6. Too far in future (over 2 years)
echo "6. Too Far in Future..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Future Event",
    "expires_at": "2030-01-01"
  }' | jq .
echo -e "\n"

# 7. Non-existent child
echo "7. Non-existent Child..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 999,
    "event_name": "Orphan Event",
    "expires_at": "2025-12-25"
  }' | jq .
echo -e "\n"

# 8. Duplicate event name (same child, same name, active)
echo "8. Duplicate Event Name..."
curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "event_name": "Emma'\''s 9th Birthday Party",
    "expires_at": "2026-08-01"
  }' | jq .
echo -e "\n"

# 9. Event for different child (should work)
echo "9. Event for Different Child..."
# First get or create another child
CHILD_COUNT=$(curl -s -X POST "$BASE_URL/api/children/list" -H "Content-Type: application/json" -d '{"parent_id": 1}' | jq '.count')
if [ "$CHILD_COUNT" -lt 2 ]; then
  echo "Creating second child for test..."
  curl -s -X POST "$BASE_URL/api/children/create" \
    -H "Content-Type: application/json" \
    -d '{
      "parent_id": 1,
      "child_name": "Oliver",
      "dob": "2019-03-10",
      "email": "oliver.test@example.com"
    }' > /dev/null
fi

# Get child_id for second child
SECOND_CHILD_ID=$(curl -s -X POST "$BASE_URL/api/children/list" -H "Content-Type: application/json" -d '{"parent_id": 1}' | jq '.children[1].child_id // .children[0].child_id')

curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": '$SECOND_CHILD_ID',
    "event_name": "Oliver'\''s 6th Birthday",
    "expires_at": "2025-12-25",
    "event_message": "Oliver is growing up so fast!",
    "videos_enabled": false
  }' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check created events with:"
echo "curl -X POST $BASE_URL/api/events/list -H \"Content-Type: application/json\" -d '{\"parent_id\": 1}' | jq ."
