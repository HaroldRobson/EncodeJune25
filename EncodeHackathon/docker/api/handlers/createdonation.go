package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Donation represents the donation data structure
type Donation struct {
	ID           int       `json:"id"`
	Message      *string   `json:"message"`
	DonorName    string    `json:"donor_name"`
	AmountPence  int       `json:"amount_pence"`
	Approved     bool      `json:"approved"`
	EventID      int       `json:"event_id"`
	CreatedAt    time.Time `json:"created_at"`
	VideoAddress *string   `json:"video_address"`
}

// CreateDonationRequest represents the request structure for creating donations
type CreateDonationRequest struct {
	EventID      int     `json:"event_id" binding:"required"`
	DonorName    string  `json:"donor_name" binding:"required"`
	AmountPence  int     `json:"amount_pence" binding:"required,min=100"` // Minimum £1.00
	Message      *string `json:"message"`
	VideoAddress *string `json:"video_address"`
}

// CreateDonationResponse represents the response after creating a donation
type CreateDonationResponse struct {
	DonationID int    `json:"donation_id"`
	Status     string `json:"status"`
	Message    string `json:"message"`
}

// CreateDonation processes a new donation
func CreateDonation(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req CreateDonationRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Verify event exists and is not expired
		eventQuery := `
			SELECT 
				e.event_id,
				e.expires_at,
				e.videos_enabled,
				pa.stripe_connect_account_id,
				pa.onboarding_complete
			FROM events e
			JOIN children c ON e.child_id = c.child_id
			JOIN parents p ON c.parent_id = p.parent_id
			LEFT JOIN payment_accounts pa ON p.parent_id = pa.parent_id
			WHERE e.event_id = $1
		`

		var eventID int
		var expiresAt time.Time
		var videosEnabled bool
		var stripeAccountID *string
		var onboardingComplete bool

		err := db.QueryRow(context.Background(), eventQuery, req.EventID).Scan(
			&eventID,
			&expiresAt,
			&videosEnabled,
			&stripeAccountID,
			&onboardingComplete,
		)
		if err != nil {
			if err.Error() == "no rows in result set" {
				c.JSON(http.StatusNotFound, gin.H{
					"error": "Event not found",
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}

		// Check if event has expired
		if time.Now().After(expiresAt) {
			c.JSON(http.StatusGone, gin.H{
				"error":      "This event has expired",
				"expired_at": expiresAt,
			})
			return
		}

		// Check if payment account is ready
		if !onboardingComplete {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"error": "Payment processing not yet available for this event",
			})
			return
		}

		// Validate video upload if provided
		if req.VideoAddress != nil && !videosEnabled {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Video uploads are not enabled for this event",
			})
			return
		}

		// Insert donation into database
		insertQuery := `
			INSERT INTO donations (message, donor_name, amount_pence, approved, event_id, video_address)
			VALUES ($1, $2, $3, $4, $5, $6)
			RETURNING id, created_at
		`

		var donationID int
		var createdAt time.Time

		err = db.QueryRow(context.Background(), insertQuery,
			req.Message,
			req.DonorName,
			req.AmountPence,
			false, // Donations start as unapproved for moderation
			req.EventID,
			req.VideoAddress,
		).Scan(&donationID, &createdAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create donation",
			})
			return
		}

		// TODO: Process Stripe payment here
		// This is where you'd integrate with Stripe to:
		// 1. Create payment intent
		// 2. Charge the donor
		// 3. Transfer to stripeAccountID
		// 4. Update donation status

		// For now, return success response
		response := CreateDonationResponse{
			DonationID: donationID,
			Status:     "pending_payment",
			Message:    "Donation created successfully. Payment processing will be implemented next.",
		}

		c.JSON(http.StatusCreated, response)
	}
}
