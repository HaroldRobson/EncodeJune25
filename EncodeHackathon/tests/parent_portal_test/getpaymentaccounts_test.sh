#!/bin/bash

# Get Payment Accounts Status API Testing
# Run: docker compose up -d

echo "📊 Testing Get Payment Accounts Status API"
echo "=========================================="

BASE_URL="http://localhost:8080"

# Setup: Create test parents in different payment states
echo "🔧 Setting up test data..."

# Parent 1: No payment account
PARENT1_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "nopayment@example.com",
    "auth0_id": "auth0|nopayment123"
  }')
PARENT1_ID=$(echo $PARENT1_RESPONSE | jq -r '.parent_id')
echo "Created parent 1 (no payment): $PARENT1_ID"

# Parent 2: Payment account but no onboarding
PARENT2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "pending@example.com",
    "auth0_id": "auth0|pending123"
  }')
PARENT2_ID=$(echo $PARENT2_RESPONSE | jq -r '.parent_id')

curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT2_ID,
    \"stripe_connect_account_id\": \"acct_1PendingOnboarding\"
  }" > /dev/null
echo "Created parent 2 (pending onboarding): $PARENT2_ID"

# Parent 3: Complete payment setup
PARENT3_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "complete@example.com",
    "auth0_id": "auth0|complete123"
  }')
PARENT3_ID=$(echo $PARENT3_RESPONSE | jq -r '.parent_id')

curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT3_ID,
    \"stripe_connect_account_id\": \"acct_1CompleteSetup123\"
  }" > /dev/null

curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d '{
    "stripe_connect_account_id": "acct_1CompleteSetup123"
  }' > /dev/null
echo "Created parent 3 (complete setup): $PARENT3_ID"
echo ""

# 1. Parent with no payment account
echo "1. Parent with No Payment Account..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT1_ID
  }" | jq .
echo -e "\n"

# 2. Parent with pending onboarding
echo "2. Parent with Pending Onboarding..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT2_ID
  }" | jq .
echo -e "\n"

# 3. Parent with complete setup
echo "3. Parent with Complete Setup..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT3_ID
  }" | jq .
echo -e "\n"

# 4. Sample parent status (from initial data)
echo "4. Sample Parent Status..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 1
  }' | jq .
echo -e "\n"

# 5. Missing parent_id
echo "5. Missing Parent ID..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
echo -e "\n"

# 6. Non-existent parent
echo "6. Non-existent Parent..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 99999
  }' | jq .
echo -e "\n"

# 7. Invalid parent_id type
echo "7. Invalid Parent ID Type..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": "not_a_number"
  }' | jq .
echo -e "\n"

# 8. Zero parent_id
echo "8. Zero Parent ID..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": 0
  }' | jq .
echo -e "\n"

# 9. Negative parent_id
echo "9. Negative Parent ID..."
curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_id": -1
  }' | jq .
echo -e "\n"

# 10. Check multiple parents quickly
echo "10. Multiple Parent Status Check..."
for id in $PARENT1_ID $PARENT2_ID $PARENT3_ID; do
  echo "Parent $id status:"
  curl -s -X POST "$BASE_URL/api/payments/status" \
    -H "Content-Type: application/json" \
    -d "{\"parent_id\": $id}" | jq -r '.status'
done
echo -e "\n"

echo "✅ Testing Complete!"
echo ""
echo "🔍 Check all payment accounts:"
echo "docker exec donations_db psql -U postgres -d donations -c \"SELECT pa.account_id, pa.parent_id, p.parent_email, pa.stripe_connect_account_id, pa.onboarding_complete FROM payment_accounts pa JOIN parents p ON pa.parent_id = p.parent_id ORDER BY pa.created_at DESC;\""
echo ""
echo "📊 Status Summary:"
echo "- no_account: Parent needs to set up Stripe"
echo "- pending_onboarding: Account created, needs to complete verification"
echo "- ready: Fully set up and can receive donations"
echo ""
echo "💡 Frontend Dashboard Usage:"
echo "   1. Call this endpoint when parent logs in"
echo "   2. Show appropriate UI based on status"
echo "   3. Guide parent through setup steps"
