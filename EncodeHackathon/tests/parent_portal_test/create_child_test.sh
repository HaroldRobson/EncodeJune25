#!/bin/bash

# Create Child API Testing
# Run: docker compose up -d

echo "👶 Testing Create Child API"
echo "============================"

BASE_URL="http://localhost:8080"

# 1. Valid child creation
echo "1. Valid Child Creation..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Oliver",
    "dob": "2020-05-15",
    "email": "oliver@example.com"
  }' | jq .
echo -e "\n"

# 2. Another valid child
echo "2. Another Valid Child..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Lily",
    "dob": "2018-12-03",
    "email": "lily@example.com"
  }' | jq .
echo -e "\n"

# 3. Missing required fields
echo "3. Missing Required Fields..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Missing Fields"
  }' | jq .
echo -e "\n"

# 4. Invalid date format
echo "4. Invalid Date Format..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Bad Date",
    "dob": "15-07-2020",
    "email": "baddate@example.com"
  }' | jq .
echo -e "\n"

# 5. Future date of birth
echo "5. Future Date of Birth..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Future Baby",
    "dob": "2030-01-01",
    "email": "future@example.com"
  }' | jq .
echo -e "\n"

# 6. Child too old (over 18)
echo "6. Child Too Old (Over 18)..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Too Old",
    "dob": "2000-01-01",
    "email": "toold@example.com"
  }' | jq .
echo -e "\n"

# 7. Duplicate email
echo "7. Duplicate Email..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Duplicate Email",
    "dob": "2019-06-10",
    "email": "oliver@example.com"
  }' | jq .
echo -e "\n"

# 8. Non-existent parent
echo "8. Non-existent Parent..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 999,
    "child_name": "Orphan Child",
    "dob": "2019-01-01",
    "email": "orphan@example.com"
  }' | jq .
echo -e "\n"

# 9. Invalid email format
echo "9. Invalid Email Format..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Bad Email",
    "dob": "2019-01-01",
    "email": "not-an-email"
  }' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check created children with:"
echo "curl -X POST $BASE_URL/api/children/list -H \"Content-Type: application/json\" -d '{\"parent_id\": 1}' | jq ."


# 10. Same child name (should be allowed - different families can have same names)
echo "10. Same Child Name (Should Be Allowed)..."
curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "child_name": "Emma",
    "dob": "2019-01-01",
    "email": "emma2@example.com"
  }' | jq .
echo -e "\n"
