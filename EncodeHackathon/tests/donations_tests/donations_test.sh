#!/bin/bash

# Create Donation API Testing
# Run: docker compose up -d

echo "🎁 Testing Create Donation API"
echo "=============================="

BASE_URL="http://localhost:8080"

# 1. Valid donation (£5.00)
echo "1. Valid Donation (£5.00)..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 1,
    "donor_name": "Uncle Bob",
    "amount_pence": 500,
    "message": "Happy birthday Emma! Have a wonderful day! 🎂"
  }' | jq .
echo -e "\n"

# 2. Valid donation with video
echo "2. Valid Donation with Video..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 1,
    "donor_name": "Grandma Sarah",
    "amount_pence": 1000,
    "message": "Love you so much sweetie!",
    "video_address": "https://example.com/birthday-video.mp4"
  }' | jq .
echo -e "\n"

# 3. Minimum donation (£1.00)
echo "3. Minimum Donation (£1.00)..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 1,
    "donor_name": "Friend Alex",
    "amount_pence": 100,
    "message": "Hope you have the best day!"
  }' | jq .
echo -e "\n"

# 4. Too small donation (50p - should fail)
echo "4. Too Small Donation (50p - should fail)..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 1,
    "donor_name": "Cheap Charlie",
    "amount_pence": 50,
    "message": "Sorry, only have 50p"
  }' | jq .
echo -e "\n"

# 5. Non-existent event
echo "5. Non-existent Event..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 999,
    "donor_name": "Lost Person",
    "amount_pence": 500,
    "message": "Where am I?"
  }' | jq .
echo -e "\n"

# 6. Missing required fields
echo "6. Missing Required Fields..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 1,
    "message": "Missing donor name and amount"
  }' | jq .
echo -e "\n"

# 7. Invalid JSON
echo "7. Invalid JSON..."
curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d '{"invalid": json}' | jq .
echo -e "\n"

echo "✅ Testing Complete!"
echo "Check donations were created with:"
echo "docker exec -it donations_db psql -U postgres -d donations -c 'SELECT * FROM donations;'"
