#!/bin/bash

# Save Stripe Account API Testing  
# Run: docker compose up -d
# Note: Tests client-side integration approach

echo "💳 Testing Save Stripe Account API"
echo "=================================="

BASE_URL="http://localhost:8080"

# Setup: Create test parents for Stripe account linking
echo "🔧 Setting up test parents..."
PARENT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "stripesave1@example.com",
    "auth0_id": "auth0|stripesave123"
  }')

PARENT_ID=$(echo $PARENT_RESPONSE | jq -r '.parent_id')
echo "Created test parent with ID: $PARENT_ID"

PARENT2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "stripesave2@example.com",
    "auth0_id": "auth0|stripesave456"
  }')

PARENT2_ID=$(echo $PARENT2_RESPONSE | jq -r '.parent_id')
echo "Created second test parent with ID: $PARENT2_ID"
echo ""

# 1. Valid Stripe account save
echo "1. Valid Stripe Account Save..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"stripe_connect_account_id\": \"acct_1ABCDEfghijklmno\"
  }" | jq .
echo -e "\n"

# 2. Save account for sample parent
echo "2. Account for Sample Parent..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "stripe_connect_account_id": "acct_1XYZ789sampletest"
  }' | jq .
echo -e "\n"

# 3. Missing required fields
echo "3. Missing Required Fields..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1
  }' | jq .
echo -e "\n"

# 4. Invalid Stripe account ID format
echo "4. Invalid Stripe Account ID Format..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT2_ID,
    \"stripe_connect_account_id\": \"invalid_format_123\"
  }" | jq .
echo -e "\n"

# 5. Non-existent parent
echo "5. Non-existent Parent..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 99999,
    "stripe_connect_account_id": "acct_1ValidFormat123"
  }' | jq .
echo -e "\n"

# 6. Duplicate parent account (should fail)
echo "6. Duplicate Parent Account..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"stripe_connect_account_id\": \"acct_1DifferentAccount\"
  }" | jq .
echo -e "\n"

# 7. Duplicate Stripe account ID (should fail)
echo "7. Duplicate Stripe Account ID..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT2_ID,
    \"stripe_connect_account_id\": \"acct_1ABCDEfghijklmno\"
  }" | jq .
echo -e "\n"

# 8. Valid different Stripe account ID
echo "8. Valid Different Account..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT2_ID,
    \"stripe_connect_account_id\": \"acct_1DEFGHijklmnopqr\"
  }" | jq .
echo -e "\n"

# 9. Empty Stripe account ID
echo "9. Empty Stripe Account ID..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": 1,
    \"stripe_connect_account_id\": \"\"
  }" | jq .
echo -e "\n"

# 10. Invalid JSON format
echo "10. Invalid JSON Format..."
curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1,
    "stripe_connect_account_id": "acct_123",
    "extra": incomplete
  }' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo ""
echo "🔍 Check saved payment accounts:"
echo "docker exec donations_db psql -U postgres -d donations -c \"SELECT * FROM payment_accounts ORDER BY created_at DESC;\""
echo ""
echo "📝 Frontend Integration Notes:"
echo "   1. Use Stripe.js to create Connect account client-side"
echo "   2. Get account.id from Stripe response"
echo "   3. Call this endpoint to save the account ID"
echo "   4. Direct parent to Stripe onboarding flow"
echo "   5. Use webhooks to update onboarding_complete status"
