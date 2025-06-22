#!/bin/bash

# Create Parent API Testing
# Run: docker compose up -d

echo "👨‍👩‍👧‍👦 Testing Create Parent API"
echo "================================"

BASE_URL="http://localhost:8080"

# 1. Valid parent creation
echo "1. Valid Parent Creation..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "jessica.smith@newdomain.com",
    "auth0_id": "auth0|fresh123test456"
  }' | jq .
echo -e "\n"

# 2. Another valid parent
echo "2. Another Valid Parent..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "robert.jones@anotherdomain.com", 
    "auth0_id": "auth0|brand789new012"
  }' | jq .
echo -e "\n"

# 3. Missing required fields
echo "3. Missing Required Fields..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "incomplete@example.com"
  }' | jq .
echo -e "\n"

# 4. Invalid email format
echo "4. Invalid Email Format..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "not-an-email",
    "auth0_id": "auth0|valididformat"
  }' | jq .
echo -e "\n"

# 5. Invalid auth0_id format (missing prefix)
echo "5. Invalid Auth0 ID Format..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "badauth@example.com",
    "auth0_id": "justplaintext123"
  }' | jq .
echo -e "\n"

# 6. Duplicate auth0_id
echo "6. Duplicate Auth0 ID..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "different.email@newdomain.com",
    "auth0_id": "auth0|fresh123test456"
  }' | jq .
echo -e "\n"

# 7. Duplicate email
echo "7. Duplicate Email..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "jessica.smith@newdomain.com",
    "auth0_id": "auth0|totallydifferent999"
  }' | jq .
echo -e "\n"

# 8. Empty auth0_id
echo "8. Empty Auth0 ID..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "empty@example.com",
    "auth0_id": ""
  }' | jq .
echo -e "\n"

# 9. Valid auth0_id with different format variations
echo "9. Valid Auth0 ID Variations..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "variation.test@uniquedomain.com",
    "auth0_id": "auth0|google-oauth2|9876543210"
  }' | jq .
echo -e "\n"

# 10. Special characters in email (should be valid)
echo "10. Special Characters in Email..."
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "test.email+tag@special-domain.co.uk",
    "auth0_id": "auth0|specialemail456"
  }' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check all created parents by querying the database:"
echo "docker exec donations_db psql -U postgres -d donations -c \"SELECT * FROM parents ORDER BY created_at DESC;\""
