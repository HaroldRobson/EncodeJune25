#!/bin/bash

# Get Events API Testing
# Run: docker compose up -d

echo "🎉 Testing Get Events API"
echo "=========================="

BASE_URL="http://localhost:8080"

# First, add some test events
echo "Setting up test data..."
docker exec -it donations_db psql -U postgres -d donations -c "
-- Add more children if needed
INSERT INTO children (DOB, parent_id, email, isa_expiry, child_name) VALUES
('2016-12-25', 1, 'charlie@example.com', '2034-12-25', 'Charlie')
ON CONFLICT (email) DO NOTHING;

-- Add some test events
INSERT INTO events (child_id, event_name, expires_at, event_message, videos_enabled, photo_address) VALUES
(1, 'Emma''s 9th Birthday', '2026-07-15', 'Emma is turning 9! Let''s make it special!', true, 'https://example.com/emma9.jpg'),
(1, 'Emma''s Christmas Fund', '2025-12-20', 'Help make Emma''s Christmas magical!', false, 'https://example.com/xmas.jpg'),
((SELECT child_id FROM children WHERE child_name = 'Charlie' LIMIT 1), 'Charlie''s 10th Birthday', '2026-12-25', 'Charlie''s double-digit birthday!', true, 'https://example.com/charlie.jpg')
ON CONFLICT DO NOTHING;
"

echo -e "\n"

# 1. Valid request (parent_id = 1)
echo "1. Valid Request (Parent ID: 1)..."
curl -s -X POST "$BASE_URL/api/events/list" \
  -H "Content-Type: application/json" \
  -d '{"parent_id": 1}' | jq .
echo -e "\n"

# 2. Non-existent parent
echo "2. Non-existent Parent (ID: 999)..."
curl -s -X POST "$BASE_URL/api/events/list" \
  -H "Content-Type: application/json" \
  -d '{"parent_id": 999}' | jq .
echo -e "\n"

# 3. Missing parent_id
echo "3. Missing parent_id..."
curl -s -X POST "$BASE_URL/api/events/list" \
  -H "Content-Type: application/json" \
  -d '{"wrong_field": 123}' | jq .
echo -e "\n"

# 4. Invalid JSON
echo "4. Invalid JSON..."
curl -s -X POST "$BASE_URL/api/events/list" \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}' | jq .
echo -e "\n"

# 5. Add an expired event and test
echo "5. Adding expired event and testing..."
docker exec -it donations_db psql -U postgres -d donations -c "
INSERT INTO events (child_id, event_name, expires_at, event_message, videos_enabled) VALUES
(1, 'Emma''s Past Birthday', '2020-07-15', 'This event has expired', false);
"

echo "6. Query including expired event..."
curl -s -X POST "$BASE_URL/api/events/list" \
  -H "Content-Type: application/json" \
  -d '{"parent_id": 1}' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Events should be ordered by expiry date (earliest first)"
echo "Check is_expired and days_remaining fields"
