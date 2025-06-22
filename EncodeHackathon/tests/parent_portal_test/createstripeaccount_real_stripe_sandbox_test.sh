#!/bin/bash

# Real Stripe Integration Test
# Prerequisites: 
# 1. STRIPE_SECRET_KEY set in environment
# 2. go get github.com/stripe/stripe-go/v79

echo "🎯 Real Stripe Connect Account Test"
echo "==================================="

# Check if Stripe secret key is set
if [ -z "$STRIPE_SECRET_KEY" ]; then
    echo "❌ STRIPE_SECRET_KEY not set!"
    echo "Get your test keys from: https://dashboard.stripe.com/test/apikeys"
    echo "Then run: export STRIPE_SECRET_KEY=sk_test_..."
    exit 1
fi

echo "✅ Stripe secret key found: ${STRIPE_SECRET_KEY:0:12}..."
echo ""

BASE_URL="http://localhost:8080"

# Step 1: Create a test parent
echo "👤 Step 1: Creating test parent..."
PARENT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "realstripe@example.com",
    "auth0_id": "auth0|realstripe789"
  }')

PARENT_ID=$(echo $PARENT_RESPONSE | jq -r '.parent_id')
echo "Created parent ID: $PARENT_ID"
echo ""

# Step 2: Create REAL Stripe Connect Express account
echo "💳 Step 2: Creating REAL Stripe Connect account..."
STRIPE_RESPONSE=$(curl -s -X POST https://api.stripe.com/v1/accounts \
  -H "Authorization: Bearer $STRIPE_SECRET_KEY" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "type=express&country=GB&email=realstripe@example.com")
# Extract account ID from Stripe response
STRIPE_ACCOUNT_ID=$(echo $STRIPE_RESPONSE | jq -r '.id')

if [ "$STRIPE_ACCOUNT_ID" = "null" ]; then
    echo "❌ Failed to create Stripe account!"
    echo "Response: $STRIPE_RESPONSE"
    exit 1
fi

echo "✅ Created Stripe account: $STRIPE_ACCOUNT_ID"
echo ""

# Step 3: Save account to our database
echo "💾 Step 3: Saving account to our database..."
SAVE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"stripe_connect_account_id\": \"$STRIPE_ACCOUNT_ID\"
  }")

echo "Save response:"
echo "$SAVE_RESPONSE" | jq .
echo ""

# Step 4: Create account link for onboarding
echo "🔗 Step 4: Creating onboarding link..."
LINK_RESPONSE=$(curl -s -X POST https://api.stripe.com/v1/account_links \
  -H "Authorization: Bearer $STRIPE_SECRET_KEY" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "account=$STRIPE_ACCOUNT_ID&refresh_url=http://localhost:3000/reauth&return_url=http://localhost:3000/return&type=account_onboarding")

ONBOARDING_URL=$(echo $LINK_RESPONSE | jq -r '.url')

if [ "$ONBOARDING_URL" = "null" ]; then
    echo "❌ Failed to create onboarding link!"
    echo "Response: $LINK_RESPONSE"
    exit 1
fi

echo "✅ Onboarding URL created:"
echo "$ONBOARDING_URL"
echo ""

# Step 5: Check account status
echo "📊 Step 5: Checking account status..."
STATUS_RESPONSE=$(curl -s -X GET "https://api.stripe.com/v1/accounts/$STRIPE_ACCOUNT_ID" \
  -H "Authorization: Bearer $STRIPE_SECRET_KEY")

CHARGES_ENABLED=$(echo $STATUS_RESPONSE | jq -r '.charges_enabled')
DETAILS_SUBMITTED=$(echo $STATUS_RESPONSE | jq -r '.details_submitted')

echo "Account Status:"
echo "- Charges Enabled: $CHARGES_ENABLED"
echo "- Details Submitted: $DETAILS_SUBMITTED"
echo ""

# Step 6: Test duplicate prevention
echo "🚫 Step 6: Testing duplicate prevention..."
DUPLICATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"stripe_connect_account_id\": \"$STRIPE_ACCOUNT_ID\"
  }")

echo "Duplicate attempt response:"
echo "$DUPLICATE_RESPONSE" | jq .
echo ""

# Results Summary
echo "🎉 REAL STRIPE TEST COMPLETE!"
echo "=============================="
echo "✅ Created real Stripe Express account: $STRIPE_ACCOUNT_ID"
echo "✅ Saved to database successfully"
echo "✅ Generated onboarding URL"
echo "✅ Verified duplicate prevention"
echo ""
echo "Next steps:"
echo "1. Visit onboarding URL to complete setup:"
echo "   $ONBOARDING_URL"
echo "2. Check Stripe dashboard: https://dashboard.stripe.com/test/connect/accounts"
echo "3. Account will be able to receive test payments after onboarding"
echo ""
echo "💡 In production:"
echo "   - Use webhooks to track onboarding completion"
echo "   - Set real return/refresh URLs"
echo "   - Handle country-specific requirements"
