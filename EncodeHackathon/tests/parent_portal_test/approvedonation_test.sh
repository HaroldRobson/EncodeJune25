#!/bin/bash

# Approve Donation API Testing
# Run: docker compose up -d

echo "✅ Testing Approve Donation API"
echo "================================"

BASE_URL="http://localhost:8080"

# First, let's get a list of donations to find some IDs to work with
echo "Getting donation IDs for testing..."
DONATION_DATA=$(curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"event_id": 1}')

# Extract first pending donation ID
PENDING_DONATION_ID=$(echo "$DONATION_DATA" | jq -r '.donations[] | select(.approved == false) | .id' | head -n 1)
APPROVED_DONATION_ID=$(echo "$DONATION_DATA" | jq -r '.donations[] | select(.approved == true) | .id' | head -n 1)

echo "Found pending donation ID: $PENDING_DONATION_ID"
echo "Found approved donation ID: $APPROVED_DONATION_ID"
echo -e "\n"

# 1. Approve a pending donation
echo "1. Approve Pending Donation (ID: $PENDING_DONATION_ID)..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": '$PENDING_DONATION_ID',
    "approved": true
  }' | jq .
echo -e "\n"

# 2. Reject a donation (find another pending one or create one)
echo "2. Adding new donation to reject..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 1,
    "donor_name": "Suspicious Person",
    "amount_pence": 100,
    "message": "This message should be rejected..."
  }' > /dev/null

# Get the new donation ID
NEW_DONATION_DATA=$(curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d '{"event_id": 1}')
NEW_DONATION_ID=$(echo "$NEW_DONATION_DATA" | jq -r '.donations[0].id')

echo "3. Reject New Donation (ID: $NEW_DONATION_ID)..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": '$NEW_DONATION_ID',
    "approved": false
  }' | jq .
echo -e "\n"

# 4. Try to approve an already approved donation
echo "4. Try to Approve Already Approved Donation..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": '$APPROVED_DONATION_ID',
    "approved": true
  }' | jq .
echo -e "\n"

# 5. Non-existent donation
echo "5. Non-existent Donation (ID: 99999)..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": 99999,
    "approved": true
  }' | jq .
echo -e "\n"

# 6. Missing required fields
echo "6. Missing Required Fields..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": '$PENDING_DONATION_ID'
  }' | jq .
echo -e "\n"

# 7. Invalid JSON
echo "7. Invalid JSON..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}' | jq .
echo -e "\n"

# 8. Change approval status back and forth
echo "8. Toggle Approval Status..."
echo "  8a. Reject previously approved donation..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": '$PENDING_DONATION_ID',
    "approved": false
  }' | jq .
echo -e "\n"

echo "  8b. Approve it again..."
curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d '{
    "donation_id": '$PENDING_DONATION_ID',
    "approved": true
  }' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check final donation statuses:"
echo "curl -X POST $BASE_URL/api/donations/list -H \"Content-Type: application/json\" -d '{\"event_id\": 1}' | jq '.donations[] | {id, donor_name, approved}'"
