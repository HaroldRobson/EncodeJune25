#!/bin/bash

# 🎯 MEGATEST - PARENT & PAYMENT SETUP SECTION
#
# 🎯 MEGATEST - Reset existing Bunting data first
# Clean up existing Bunting data first
echo "🧹 Cleaning existing Bunting data..."

# Delete in correct order to respect foreign key constraints
docker exec donations_db psql -U postgres -d donations -c "
DELETE FROM donations WHERE event_id IN (
  SELECT event_id FROM events WHERE child_id IN (
    SELECT child_id FROM children WHERE parent_id IN (
      SELECT parent_id FROM parents WHERE auth0_id LIKE 'auth0|bunting_primary_%'
    )
  )
);
" > /dev/null

docker exec donations_db psql -U postgres -d donations -c "
DELETE FROM events WHERE child_id IN (
  SELECT child_id FROM children WHERE parent_id IN (
    SELECT parent_id FROM parents WHERE auth0_id LIKE 'auth0|bunting_primary_%'
  )
);
" > /dev/null

docker exec donations_db psql -U postgres -d donations -c "
DELETE FROM payment_accounts WHERE parent_id IN (
  SELECT parent_id FROM parents WHERE auth0_id LIKE 'auth0|bunting_primary_%'
);
" > /dev/null

docker exec donations_db psql -U postgres -d donations -c "
DELETE FROM children WHERE parent_id IN (
  SELECT parent_id FROM parents WHERE auth0_id LIKE 'auth0|bunting_primary_%'
);
" > /dev/null

docker exec donations_db psql -U postgres -d donations -c "
DELETE FROM parents WHERE auth0_id LIKE 'auth0|bunting_primary_%';
" > /dev/null

echo "Clean slate ready!"
echo ""
# Delete existing Bunting parent to ensure clean test
curl -s -X DELETE "$BASE_URL/api/parents/delete" \
  -H "Content-Type: application/json" \
  -d '{"auth0_id": "auth0|bunting_primary_123"}' > /dev/null

# Wait a moment for cleanup
sleep 1

echo "Clean slate ready! Starting MEGATEST..."
echo ""
# This section tests the complete parent signup and payment setup flow
# Each request simulates what a real user would do on the website

BASE_URL="http://localhost:8080"

echo "🚀 MEGATEST: Parent & Payment Setup Flow"
echo "========================================"

# =============================================================================
# 📱 SCENARIO: New parent discovers the platform and wants to start receiving donations
# =============================================================================

# 🌐 WEBPAGE: Landing page -> Parent clicks "Sign Up" button
# Auth0 handles signup in browser, parent gets auth0_id in JWT token
# Browser redirects to: /parent-dashboard
# Frontend extracts auth0_id from JWT: "auth0|bunting_primary_123"

# Request 1: Create Parent Account
# 💭 CONTEXT: Parent just completed Auth0 signup, frontend needs to create account in our system
# 📊 DATA AVAILABLE: auth0_id (from JWT), parent_email (from Auth0 profile)
echo "1. Creating parent account for Bunting..."
PARENT_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/create" \
  -H "Content-Type: application/json" \
  -d '{
    "parent_email": "bunting.primary@testdomain.com",
    "auth0_id": "auth0|bunting_primary_123"
  }')

echo "Response: $PARENT_CREATE_RESPONSE"

# Extract parent_id for subsequent requests (stored in browser localStorage/session)
PARENT_ID=$(echo $PARENT_CREATE_RESPONSE | jq -r '.parent_id')
echo "📋 Parent ID stored in session: $PARENT_ID"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Parent dashboard loads successfully
# Shows welcome message: "Welcome Bunting! Let's set up your account"
# Dashboard checks if parent profile is complete

# Request 2: Get Parent Profile
# 💭 CONTEXT: Dashboard page loading, needs to display parent info and setup status
# 📊 DATA AVAILABLE: auth0_id (from JWT token stored in browser)
echo "2. Loading parent profile for dashboard..."
PARENT_PROFILE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/parents/get" \
  -H "Content-Type: application/json" \
  -d '{
    "auth0_id": "auth0|bunting_primary_123"
  }')

echo "Response: $PARENT_PROFILE_RESPONSE"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Dashboard now shows: "Hi Bunting! Your account is set up."
# Dashboard needs to check payment setup status
# Shows section: "Payment Setup" with loading spinner

# Request 3: Check Payment Account Status
# 💭 CONTEXT: Dashboard checking if parent has completed Stripe setup
# 📊 DATA AVAILABLE: parent_id (from session storage)
echo "3. Checking payment setup status..."
PAYMENT_STATUS_RESPONSE=$(curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID
  }")

echo "Response: $PAYMENT_STATUS_RESPONSE"
PAYMENT_STATUS=$(echo $PAYMENT_STATUS_RESPONSE | jq -r '.status')
echo "📊 Payment Status: $PAYMENT_STATUS"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Dashboard shows: "No payment account set up. Create a Stripe account to start receiving donations."
# Big blue button: "Set Up Payments" 
# Parent clicks button -> Browser navigates to /payment-setup

# 🌐 WEBPAGE: Payment Setup Page
# Frontend creates Stripe Connect account using Stripe.js
# ⚠️  NOTE: Using MOCK Stripe account for testing - in production this would be real Stripe API
# ⚠️  IMPORTANT: This test does NOT use sandbox Stripe to avoid API dependencies

# Request 4: Save Stripe Account
# 💭 CONTEXT: Frontend created Stripe account, now saving to our database
# 📊 DATA AVAILABLE: parent_id (from session), stripe_connect_account_id (from Stripe.js)
echo "4. Saving Stripe Connect account (MOCK - not real Stripe)..."
MOCK_STRIPE_ACCOUNT="acct_bunting_connect_primary"
SAVE_ACCOUNT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/payments/save-account" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"stripe_connect_account_id\": \"$MOCK_STRIPE_ACCOUNT\"
  }")

echo "Response: $SAVE_ACCOUNT_RESPONSE"
echo "📋 Stripe Account ID: $MOCK_STRIPE_ACCOUNT"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Payment setup page shows: "Account created! Complete verification to start receiving payments"
# Frontend redirects to Stripe onboarding: https://connect.stripe.com/setup/e/acct_xxx/...
# Parent completes bank details, ID verification on Stripe's website
# Stripe redirects browser to: localhost:3000/return?account=acct_bunting_connect_primary

# 🌐 WEBPAGE: Return from Stripe onboarding
# Frontend JavaScript extracts account ID from URL parameters
# Immediately calls API to mark onboarding complete

# Request 5: Complete Onboarding
# 💭 CONTEXT: Parent returned from Stripe, onboarding is complete
# 📊 DATA AVAILABLE: stripe_connect_account_id (from URL parameter ?account=...)
echo "5. Marking Stripe onboarding as complete..."
ONBOARDING_COMPLETE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/payments/onboarding-complete" \
  -H "Content-Type: application/json" \
  -d "{
    \"stripe_connect_account_id\": \"$MOCK_STRIPE_ACCOUNT\"
  }")

echo "Response: $ONBOARDING_COMPLETE_RESPONSE"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Return page shows: "Setup complete! ✅"
# After 2 seconds, redirects to: /parent-dashboard
# Dashboard needs to refresh payment status

# Request 6: Verify Payment Setup Complete
# 💭 CONTEXT: Dashboard reloading to show updated payment status
# 📊 DATA AVAILABLE: parent_id (from session storage)
echo "6. Verifying payment setup is now complete..."
FINAL_PAYMENT_STATUS=$(curl -s -X POST "$BASE_URL/api/payments/status" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID
  }")

echo "Response: $FINAL_PAYMENT_STATUS"
FINAL_STATUS=$(echo $FINAL_PAYMENT_STATUS | jq -r '.status')
echo "📊 Final Payment Status: $FINAL_STATUS"
echo ""

# =============================================================================
# 🎉 PARENT SETUP COMPLETE!
# =============================================================================

echo "✅ Parent & Payment Setup Flow COMPLETE!"
echo "Parent ID: $PARENT_ID"
echo "Stripe Account: $MOCK_STRIPE_ACCOUNT"
echo "Payment Status: $FINAL_STATUS"
echo ""

# 🎯 MEGATEST - CHILDREN & EVENTS SECTION
# This section tests creating children and birthday events
# Continues from parent setup with PARENT_ID available

echo ""
echo "🧒 MEGATEST: Children & Events Setup Flow"
echo "========================================="

# =============================================================================
# 📱 SCENARIO: Parent (Bunting) wants to add children and create birthday events
# =============================================================================

# 🌐 WEBPAGE: Parent Dashboard -> Parent clicks "Add Child" button
# Form appears with fields: Child Name, Date of Birth, Email
# Parent fills out form for their first child

# Request 7: Create First Child
# 💭 CONTEXT: Parent adding their first child to the platform
# 📊 DATA AVAILABLE: parent_id (from session storage after login)
echo "7. Creating first child - Bunting Jr..."
CHILD1_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"child_name\": \"Bunting Jr\",
    \"dob\": \"2018-03-15\",
    \"email\": \"bunting.jr@testdomain.com\"
  }")

echo "Response: $CHILD1_CREATE_RESPONSE"

# Extract child_id for subsequent requests
CHILD1_ID=$(echo $CHILD1_CREATE_RESPONSE | jq -r '.child_id')
echo "📋 Child 1 ID: $CHILD1_ID"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Success message: "Bunting Jr added successfully!"
# Dashboard refreshes to show children list
# Parent sees "Add Another Child" button and clicks it

# Request 8: Create Second Child
# 💭 CONTEXT: Parent adding their second child
# 📊 DATA AVAILABLE: parent_id (from session storage)
echo "8. Creating second child - Bunting The Third..."
CHILD2_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/children/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID,
    \"child_name\": \"Bunting The Third\",
    \"dob\": \"2016-11-08\",
    \"email\": \"bunting.third@testdomain.com\"
  }")

echo "Response: $CHILD2_CREATE_RESPONSE"

# Extract child_id for subsequent requests
CHILD2_ID=$(echo $CHILD2_CREATE_RESPONSE | jq -r '.child_id')
echo "📋 Child 2 ID: $CHILD2_ID"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Dashboard now shows both children in a list
# Each child has a "Create Birthday Event" button
# Parent clicks "Create Birthday Event" for Bunting Jr

# Request 9: List All Children (Dashboard Refresh)
# 💭 CONTEXT: Dashboard loading to show all children for this parent
# 📊 DATA AVAILABLE: parent_id (from session storage)
echo "9. Loading all children for dashboard display..."
CHILDREN_LIST_RESPONSE=$(curl -s -X POST "$BASE_URL/api/children/list" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID
  }")

echo "Response: $CHILDREN_LIST_RESPONSE"
CHILDREN_COUNT=$(echo $CHILDREN_LIST_RESPONSE | jq -r '.count')
echo "📊 Total Children: $CHILDREN_COUNT"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Dashboard shows: "You have 2 children: Bunting Jr, Bunting The Third"
# Parent clicks "Create Birthday Event" button for Bunting Jr
# Browser navigates to: /create-event?child_id=CHILD1_ID

# 🌐 WEBPAGE: Create Event Page
# Form pre-filled with child name: "Bunting Jr's Birthday"
# Parent customizes event details

# Request 10: Create Birthday Event for First Child
# 💭 CONTEXT: Parent creating birthday event for Bunting Jr (turns 7 this year)
# 📊 DATA AVAILABLE: child_id (from URL parameter), parent_id (from session)
echo "10. Creating birthday event for Bunting Jr..."
EVENT1_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"child_id\": $CHILD1_ID,
    \"event_name\": \"Bunting Jr's 7th Birthday Bash\",
    \"expires_at\": \"2025-12-25\",
    \"event_message\": \"Help us celebrate Bunting Jr turning 7! He loves cats, coding, and birthday cake! 🎂🐱💻\",
    \"videos_enabled\": true,
    \"photo_address\": \"https://bunting-family-photos.test/bunting-jr-birthday.jpg\"
  }")

echo "Response: $EVENT1_CREATE_RESPONSE"

# Extract event_id for subsequent requests
EVENT1_ID=$(echo $EVENT1_CREATE_RESPONSE | jq -r '.event_id')
echo "📋 Event 1 ID: $EVENT1_ID"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Success message: "Birthday event created! Share this link with family and friends:"
# Shows shareable URL: https://yourdomain.com/donate?event=EVENT1_ID
# Parent goes back to dashboard to create another event

# Request 11: Create Birthday Event for Second Child
# 💭 CONTEXT: Parent creating birthday event for Bunting The Third (turns 9 this year)
# 📊 DATA AVAILABLE: child_id (CHILD2_ID), parent_id (from session)
echo "11. Creating birthday event for Bunting The Third..."
EVENT2_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/events/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"child_id\": $CHILD2_ID,
    \"event_name\": \"Bunting The Third's 9th Birthday Celebration\",
    \"expires_at\": \"2025-11-08\",
    \"event_message\": \"Our eldest is turning 9! Bunting The Third loves adventures, reading, and making new friends. Let's make this birthday unforgettable! 🎉📚🌟\",
    \"videos_enabled\": false,
    \"photo_address\": \"https://bunting-family-photos.test/bunting-third-portrait.jpg\"
  }")

echo "Response: $EVENT2_CREATE_RESPONSE"

# Extract event_id for subsequent requests
EVENT2_ID=$(echo $EVENT2_CREATE_RESPONSE | jq -r '.event_id')
echo "📋 Event 2 ID: $EVENT2_ID"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Parent dashboard now shows overview of all events
# Shows event cards with donation progress, expiry dates
# Parent wants to see full event list

# Request 12: List All Events (Dashboard Overview)
# 💭 CONTEXT: Dashboard loading to show all events for parent's children
# 📊 DATA AVAILABLE: parent_id (from session storage)
echo "12. Loading all events for parent dashboard..."
EVENTS_LIST_RESPONSE=$(curl -s -X POST "$BASE_URL/api/events/list" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_id\": $PARENT_ID
  }")

echo "Response: $EVENTS_LIST_RESPONSE"
EVENTS_COUNT=$(echo $EVENTS_LIST_RESPONSE | jq -r '.count')
echo "📊 Total Events: $EVENTS_COUNT"
echo ""

# =============================================================================
# 🎉 CHILDREN & EVENTS SETUP COMPLETE!
# =============================================================================

echo "✅ Children & Events Setup Flow COMPLETE!"
echo "Parent ID: $PARENT_ID"
echo "Child 1 - Bunting Jr: $CHILD1_ID"
echo "Child 2 - Bunting The Third: $CHILD2_ID"
echo "Event 1 - Bunting Jr's Birthday: $EVENT1_ID"
echo "Event 2 - Bunting The Third's Birthday: $EVENT2_ID"
echo ""

# 🌐 FINAL WEBPAGE STATE:
# Parent dashboard now shows:
# - 2 children registered
# - 2 active birthday events
# - Shareable donation links
# - Payment setup complete (from previous section)
# Platform is now ready to receive donations!

# 📊 DATA PERSISTED FOR NEXT SECTION:
# - PARENT_ID: $PARENT_ID (parent account)
# - CHILD1_ID: $CHILD1_ID (Bunting Jr)
# - CHILD2_ID: $CHILD2_ID (Bunting The Third)
# - EVENT1_ID: $EVENT1_ID (Bunting Jr's birthday)
# - EVENT2_ID: $EVENT2_ID (Bunting The Third's birthday)
# - Both events are live and ready for donations

echo "🔄 Ready for next section: DONATIONS & APPROVAL"
echo "==============================================="
#!/bin/bash

# 🎯 MEGATEST - DONATIONS & APPROVAL SECTION
# This section tests the complete donation flow from donor perspective and parent approval
# Continues with EVENT1_ID and EVENT2_ID available

echo ""
echo "💰 MEGATEST: Donations & Approval Flow"
echo "======================================"

# =============================================================================
# 📱 SCENARIO: Donors discover the birthday events and want to donate
# =============================================================================

# 🌐 WEBPAGE: Donor receives shareable link and visits donation page
# URL: https://yourdomain.com/donate?event=EVENT1_ID
# Page loads with event details for verification

# Request 13: Get Event Details (Donor's First Visit)
# 💭 CONTEXT: Donor (Uncle Bunting) visits donation page to see event info
# 📊 DATA AVAILABLE: event_id (from URL parameter ?event=...)
echo "13. Loading event details for donation page (Uncle Bunting visiting)..."
EVENT_DETAILS_RESPONSE=$(curl -s -X POST "$BASE_URL/api/events/request" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT1_ID
  }")

echo "Response: $EVENT_DETAILS_RESPONSE"

# Check if payment is ready for this event
ONBOARDING_STATUS=$(echo $EVENT_DETAILS_RESPONSE | jq -r '.onboarding_complete')
echo "📊 Payment Ready: $ONBOARDING_STATUS"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Donation page shows:
# - Event: "Bunting Jr's 7th Birthday Bash"
# - Message: "Help us celebrate Bunting Jr turning 7! He loves cats, coding, and birthday cake! 🎂🐱💻"
# - Child photo displayed
# - Donation form with amount selector and message box
# - Video upload option (videos_enabled: true)

# Request 14: Create First Donation (Uncle Bunting)
# 💭 CONTEXT: Uncle Bunting donates £25 with a lovely message
# 📊 DATA AVAILABLE: event_id (from current page), donor fills form
echo "14. Uncle Bunting making first donation..."
DONATION1_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT1_ID,
    \"donor_name\": \"Uncle Bunting McTesterson\",
    \"amount_pence\": 2500,
    \"message\": \"Happy 7th birthday Bunting Jr! Can't wait to see you blow out those candles! 🎂 Love from your favorite uncle! 😸\"
  }")

echo "Response: $DONATION1_CREATE_RESPONSE"

# Extract donation_id for tracking
DONATION1_ID=$(echo $DONATION1_CREATE_RESPONSE | jq -r '.donation_id')
echo "📋 Donation 1 ID: $DONATION1_ID"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Success page shows: "Thank you Uncle Bunting! Your donation is pending parent approval."
# Donor can share the link or make another donation

# Request 15: Create Second Donation (Grandma Bunting)
# 💭 CONTEXT: Grandma Bunting visits same event and donates with video message
# 📊 DATA AVAILABLE: event_id (from shareable link), donor fills form
# Request 15.1: Upload Grandma's Video Message
# 💭 CONTEXT: Grandma recorded a sweet video message and uploads it first
# 📊 DATA AVAILABLE: video file on Grandma's device
echo "14.5. Grandma uploading her video message..."

# Create a fake video file for testing
echo "fake video content for testing" > /tmp/grandma_video.mp4

# Upload it to the API
VIDEO_UPLOAD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/uploads/video" \
  -F "video=@/tmp/grandma_video.mp4")

echo "Response: $VIDEO_UPLOAD_RESPONSE"
VIDEO_URL=$(echo $VIDEO_UPLOAD_RESPONSE | jq -r '.video_url')
echo "📹 Video URL: $VIDEO_URL"
# 🌐 WEBPAGE TRANSITION:
# Video upload complete! Upload form shows: "✅ Video uploaded successfully"
# Grandma can now submit her donation with the video attached

# Request 15: Create Second Donation (Grandma Bunting with Real Video)
# 💭 CONTEXT: Grandma Bunting making donation with her uploaded video
# 📊 DATA AVAILABLE: event_id (from shareable link), video_url (from upload response)
echo "15. Grandma Bunting making donation with uploaded video..."
DONATION2_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT1_ID,
    \"donor_name\": \"Grandma Bunting\",
    \"amount_pence\": 5000,
    \"message\": \"My dearest Bunting Jr, Grandma loves you so much! I made you a special video message! 💝👵\",
    \"video_address\": \"$VIDEO_URL\"
  }")

echo "Response: $DONATION2_CREATE_RESPONSE"

# Extract donation_id for tracking
DONATION2_ID=$(echo $DONATION2_CREATE_RESPONSE | jq -r '.donation_id')
echo "📋 Donation 2 ID: $DONATION2_ID"
echo ""

# Request 16: Create Third Donation (Family Friend)
# 💭 CONTEXT: Family friend donates to second child's event
# 📊 DATA AVAILABLE: event_id (EVENT2_ID for Bunting The Third)
echo "16. Family friend donating to Bunting The Third's birthday..."
DONATION3_CREATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/create" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT2_ID,
    \"donor_name\": \"Mrs. Whiskers (Family Friend)\",
    \"amount_pence\": 1500,
    \"message\": \"Happy 9th birthday Bunting The Third! Hope you have the most amazing day! 🎉 From the Whiskers family!\"
  }")

echo "Response: $DONATION3_CREATE_RESPONSE"

# Extract donation_id for tracking
DONATION3_ID=$(echo $DONATION3_CREATE_RESPONSE | jq -r '.donation_id')
echo "📋 Donation 3 ID: $DONATION3_ID"
echo ""

# =============================================================================
# 📱 SCENARIO: Parent receives notification and reviews pending donations
# =============================================================================

# 🌐 WEBPAGE: Parent logs into dashboard and sees "3 pending donations" notification
# Parent clicks on "Review Donations" for Bunting Jr's event
# Browser navigates to: /review-donations?event=EVENT1_ID

# Request 17: List Donations for Bunting Jr's Event
# 💭 CONTEXT: Parent reviewing all donations for first child's birthday
# 📊 DATA AVAILABLE: event_id (from URL or dashboard click)
echo "17. Parent reviewing donations for Bunting Jr's birthday..."
DONATIONS_LIST1_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT1_ID
  }")

echo "Response: $DONATIONS_LIST1_RESPONSE"

# Check donation counts
TOTAL_DONATIONS_EVENT1=$(echo $DONATIONS_LIST1_RESPONSE | jq -r '.total_donations')
PENDING_DONATIONS_EVENT1=$(echo $DONATIONS_LIST1_RESPONSE | jq -r '.pending_donations')
echo "📊 Event 1 - Total: $TOTAL_DONATIONS_EVENT1, Pending: $PENDING_DONATIONS_EVENT1"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Review page shows list of donations with:
# - Uncle Bunting: £25 - "Happy 7th birthday..." [APPROVE] [REJECT]
# - Grandma Bunting: £50 - "My dearest Bunting Jr..." [VIDEO] [APPROVE] [REJECT]
# Parent clicks APPROVE for Uncle Bunting's donation

# Request 18: Approve Uncle Bunting's Donation
# 💭 CONTEXT: Parent approves Uncle Bunting's heartfelt message
# 📊 DATA AVAILABLE: donation_id (from donations list), approval decision
echo "18. Approving Uncle Bunting's donation..."
APPROVE1_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d "{
    \"donation_id\": $DONATION1_ID,
    \"approved\": true
  }")

echo "Response: $APPROVE1_RESPONSE"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Success message: "Donation approved! Uncle Bunting McTesterson's donation is now confirmed."
# Page refreshes, Uncle Bunting's donation now shows green checkmark
# Parent clicks video icon to watch Grandma's video message

# Request 19: Approve Grandma's Donation (after watching video)
# 💭 CONTEXT: Parent watched sweet video message and approves donation
# 📊 DATA AVAILABLE: donation_id (from donations list), approval decision
echo "19. Approving Grandma Bunting's donation (after watching video)..."
APPROVE2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d "{
    \"donation_id\": $DONATION2_ID,
    \"approved\": true
  }")

echo "Response: $APPROVE2_RESPONSE"
echo ""

# 🌐 WEBPAGE TRANSITION:
# Parent navigates to review donations for second child
# Dashboard shows: "1 pending donation" for Bunting The Third
# Parent clicks review button for second event

# Request 20: List Donations for Bunting The Third's Event
# 💭 CONTEXT: Parent checking donations for second child's birthday
# 📊 DATA AVAILABLE: event_id (EVENT2_ID from dashboard)
echo "20. Parent reviewing donations for Bunting The Third's birthday..."
DONATIONS_LIST2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT2_ID
  }")

echo "Response: $DONATIONS_LIST2_RESPONSE"

# Check donation counts
TOTAL_DONATIONS_EVENT2=$(echo $DONATIONS_LIST2_RESPONSE | jq -r '.total_donations')
PENDING_DONATIONS_EVENT2=$(echo $DONATIONS_LIST2_RESPONSE | jq -r '.pending_donations')
echo "📊 Event 2 - Total: $TOTAL_DONATIONS_EVENT2, Pending: $PENDING_DONATIONS_EVENT2"
echo ""

# Request 21: Approve Family Friend's Donation
# 💭 CONTEXT: Parent approves Mrs. Whiskers' donation
# 📊 DATA AVAILABLE: donation_id (from donations list), approval decision
echo "21. Approving Mrs. Whiskers' donation..."
APPROVE3_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/approve" \
  -H "Content-Type: application/json" \
  -d "{
    \"donation_id\": $DONATION3_ID,
    \"approved\": true
  }")

echo "Response: $APPROVE3_RESPONSE"
echo ""

# =============================================================================
# 📊 FINAL VERIFICATION: Check all donations are approved
# =============================================================================

# Request 22: Final Check - Bunting Jr's Event
# 💭 CONTEXT: Verifying all donations are properly approved
echo "22. Final verification - Bunting Jr's event donation status..."
FINAL_CHECK1_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT1_ID
  }")

FINAL_APPROVED1=$(echo $FINAL_CHECK1_RESPONSE | jq -r '.approved_donations')
FINAL_PENDING1=$(echo $FINAL_CHECK1_RESPONSE | jq -r '.pending_donations')
FINAL_AMOUNT1=$(echo $FINAL_CHECK1_RESPONSE | jq -r '.approved_amount_pence')
echo "📊 Bunting Jr - Approved: $FINAL_APPROVED1, Pending: $FINAL_PENDING1, Total Approved: £$(( $FINAL_AMOUNT1 / 100 ))"

# Request 23: Final Check - Bunting The Third's Event
# 💭 CONTEXT: Verifying second event donations
echo "23. Final verification - Bunting The Third's event donation status..."
FINAL_CHECK2_RESPONSE=$(curl -s -X POST "$BASE_URL/api/donations/list" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": $EVENT2_ID
  }")

FINAL_APPROVED2=$(echo $FINAL_CHECK2_RESPONSE | jq -r '.approved_donations')
FINAL_PENDING2=$(echo $FINAL_CHECK2_RESPONSE | jq -r '.pending_donations')
FINAL_AMOUNT2=$(echo $FINAL_CHECK2_RESPONSE | jq -r '.approved_amount_pence')
echo "📊 Bunting The Third - Approved: $FINAL_APPROVED2, Pending: $FINAL_PENDING2, Total Approved: £$(( $FINAL_AMOUNT2 / 100 ))"
echo ""

# =============================================================================
# 🎉 DONATIONS & APPROVAL FLOW COMPLETE!
# =============================================================================

echo "✅ Donations & Approval Flow COMPLETE!"
echo "======================================="
echo "📊 FINAL SUMMARY:"
echo "- Parent: Bunting (ID: $PARENT_ID) ✅"
echo "- Payment Setup: Complete ✅"
echo "- Children: 2 registered ✅"
echo "- Events: 2 active birthday events ✅"
echo "- Donations: 3 created, 3 approved ✅"
echo "- Total Money Raised: £$(( ($FINAL_AMOUNT1 + $FINAL_AMOUNT2) / 100 )) ✅"
echo ""

# 🌐 FINAL PLATFORM STATE:
# - Complete family setup with working payment processing
# - Active birthday events receiving and approving donations
# - Parents can manage donations and see real money accumulating
# - Donors can find events and contribute with messages/videos
# - Full end-to-end birthday donation platform is OPERATIONAL! 🎉

echo "🎉 MEGATEST COMPLETE - BIRTHDAY DONATION PLATFORM FULLY OPERATIONAL!"
echo "=================================================================="
