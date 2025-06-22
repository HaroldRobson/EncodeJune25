#!/bin/bash

# API Testing Commands for Birthday Donations API
# Run: docker compose up -d

echo "🚀 Testing Birthday Donations API"
echo "================================="

BASE_URL="http://localhost:8080"

# 1. Health Check
echo "1. Health Check..."
curl -s "$BASE_URL/health" | jq .
echo -e "\n"

# 2. Valid Event Request (should include payment fields now)
echo "2. Valid Event Request (Emma's Birthday - ID: 1)..."
curl -s -X POST "$BASE_URL/api/events/request" \
  -H "Content-Type: application/json" \
  -d '{"event_id": 1}' | jq .
echo -e "\n"

# 3. Non-existent Event
echo "3. Non-existent Event (ID: 999)..."
curl -s -X POST "$BASE_URL/api/events/request" \
  -H "Content-Type: application/json" \
  -d '{"event_id": 999}' | jq .
echo -e "\n"

# 4. Invalid JSON
echo "4. Invalid JSON..."
curl -s -X POST "$BASE_URL/api/events/request" \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}' | jq .
echo -e "\n"

# 5. Missing event_id
echo "5. Missing event_id..."
curl -s -X POST "$BASE_URL/api/events/request" \
  -H "Content-Type: application/json" \
  -d '{"wrong_field": 123}' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check that event response now includes:"
echo "  - stripe_connect_account_id: 'acct_sample123'"
echo "  - onboarding_complete: true"
