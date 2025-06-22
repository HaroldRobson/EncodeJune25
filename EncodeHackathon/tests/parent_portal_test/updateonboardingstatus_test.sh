#!/bin/bash

# Update Onboarding Status API Testing
# Run: docker compose up -d

echo "✅ Testing Update Onboarding Status API"
echo "======================================="

BASE_URL="http://localhost:8080"

# Setup: Create test parent and payment account for testing
echo "🔧 Setting up test data..."
PARENT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "onboarding@example.com",
    "auth0_id": "auth0|onboarding123"
  }')

PARENT_ID=$(echo $PARENT_RESPONSE | jq -r '.parent_id')
echo "Created test parent with ID: $PARENT_ID"

# Create payment account
ACCOUNT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"stripe_connect_account_id\": \"acct_1TestOnboarding123\"
  }")

echo "Created payment account"
echo ""

# 1. Valid onboarding completion
echo "1. Valid Onboarding Completion..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_1TestOnboarding123"
  }' | jq .
echo -e "\n"

# 2. Already completed (should be idempotent)
echo "2. Already Completed (Idempotent)..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_1TestOnboarding123"
  }' | jq .
echo -e "\n"

# 3. Test with existing sample account (if exists)
echo "3. Complete Sample Account..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_sample123"
  }' | jq .
echo -e "\n"

# 4. Missing required field
echo "4. Missing Required Field..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
echo -e "\n"

# 5. Invalid Stripe account ID format
echo "5. Invalid Account ID Format..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "invalid_format_123"
  }' | jq .
echo -e "\n"

# 6. Non-existent account
echo "6. Non-existent Account..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_1DoesNotExist999"
  }' | jq .
echo -e "\n"

# 7. Empty account ID
echo "7. Empty Account ID..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": ""
  }' | jq .
echo -e "\n"

# 8. Complete the real Stripe account from earlier test (if it exists)
echo "8. Complete Real Stripe Account..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_1RcGBtQiBhjRUgiO"
  }' | jq .
echo -e "\n"

# 9. Invalid JSON format
echo "9. Invalid JSON Format..."
curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_123",
    "extra": incomplete
  }' | jq .
echo -e "\n"

# 10. Test with account that has different format
echo "10. Different Account Format..."
# Create another test account first
curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "onboarding2@example.com",
    "auth0_id": "auth0|onboarding456"
  }' > /dev/null

PARENT2_ID=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "onboarding3@example.com",
    "auth0_id": "auth0|onboarding789"
  }' | jq -r '.parent_id')

curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT2_ID,
    \"stripe_connect_account_id\": \"acct_1DifferentFormat456\"
  }" > /dev/null

curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_1DifferentFormat456"
  }' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo ""
echo "🔍 Check onboarding status in database:"
echo "docker exec donations_db psql -U postgres -d donations -c \"SELECT account_id, parent_id, stripe_connect_account_id, onboarding_complete FROM payment_accounts ORDER BY created_at DESC;\""
echo ""
echo "📝 Frontend Integration:"
echo "   1. Stripe redirects to: localhost:3000/return?account=acct_xxx"
echo "   2. Extract account ID from URL parameters"
echo "   3. Call this endpoint to mark onboarding complete"
echo "   4. Show success message to parent"
echo "   5. Enable donation features in UI"
