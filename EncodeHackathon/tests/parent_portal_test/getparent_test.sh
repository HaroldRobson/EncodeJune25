#!/bin/bash

# Get Parent API Testing
# Run: docker compose up -d

echo "👤 Testing Get Parent API"
echo "========================="

BASE_URL="http://localhost:8080"

# First, let's create a test parent to ensure we have data
echo "🔧 Setting up test data..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "gettest@example.com",
    "auth0_id": "auth0|gettest123456"
  }' > /dev/null

echo "Test parent created. Starting tests..."
echo ""

# 1. Valid parent lookup - existing parent from sample data
echo "1. Valid Parent Lookup (Sample Data)..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|sample123"
  }' | jq .
echo -e "\n"

# 2. Valid parent lookup - newly created parent
echo "2. Valid Parent Lookup (New Parent)..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|gettest123456"
  }' | jq .
echo -e "\n"

# 3. Missing auth0_id
echo "3. Missing Auth0 ID..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
echo -e "\n"

# 4. Empty auth0_id
echo "4. Empty Auth0 ID..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": ""
  }' | jq .
echo -e "\n"

# 5. Non-existent parent
echo "5. Non-existent Parent..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|doesnotexist999"
  }' | jq .
echo -e "\n"

# 6. Invalid JSON format
echo "6. Invalid JSON Format..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|test123",
    "extra_field": incomplete
  }' | jq .
echo -e "\n"

# 7. Valid auth0_id with different format
echo "7. Different Auth0 ID Format..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|google-oauth2|1234567890"
  }' | jq .
echo -e "\n"

# 8. Auth0 ID without auth0| prefix (should still work since we don't validate format in GET)
echo "8. Auth0 ID Different Format..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "someotherprefix|123456"
  }' | jq .
echo -e "\n"

# 9. Check if any of our test parents from createparent exist
echo "9. Check Previous Test Parent..."
curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|fresh123test456"
  }' | jq .
echo -e "\n"

# 10. GET request instead of POST (should fail)
echo "10. Wrong HTTP Method (GET instead of POST)..."
curl -s -X GET "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "All existing parents in database:"
echo "docker exec donations_db psql -U postgres -d donations -c \"SELECT parent_id, parent_email, auth0_id FROM parents ORDER BY created_at DESC;\""
