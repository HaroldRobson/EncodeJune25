#!/bin/bash

# Get Children API Testing
# Run: docker compose up -d

echo "👶 Testing Get Children API"
echo "============================"

BASE_URL="http://localhost:8080"

# 1. Valid request (parent_id = 1 from sample data)
echo "1. Valid Request (Parent ID: 1)..."
curl -s -X POST "$BASE_URL/api/children/list" \
  -H "Content-Type: application/json" \
  -d '{"parent_id": 1}' | jq .
echo -e "\n"

# 2. Non-existent parent
echo "2. Non-existent Parent (ID: 999)..."
curl -s -X POST "$BASE_URL/api/children/list" \
  -H "Content-Type: application/json" \
  -d '{"parent_id": 999}' | jq .
echo -e "\n"

# 3. Missing parent_id
echo "3. Missing parent_id..."
curl -s -X POST "$BASE_URL/api/children/list" \
  -H "Content-Type: application/json" \
  -d '{"wrong_field": 123}' | jq .
echo -e "\n"

# 4. Invalid JSON
echo "4. Invalid JSON..."
curl -s -X POST "$BASE_URL/api/children/list" \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}' | jq .
echo -e "\n"

# 5. Add some test children first, then query again
echo "5. Adding test children to database..."
docker exec -it donations_db psql -U postgres -d donations -c "
INSERT INTO children (DOB, parent_id, email, isa_expiry, child_name) VALUES
('2015-03-10', 1, 'charlie@example.com', '2033-03-10', 'Charlie'),
('2019-08-22', 1, 'sophie@example.com', '2037-08-22', 'Sophie');
"

echo "6. Query after adding children..."
curl -s -X POST "$BASE_URL/api/children/list" \
  -H "Content-Type: application/json" \
  -d '{"parent_id": 1}' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Should see Emma, Charlie, and Sophie (alphabetically ordered)"
