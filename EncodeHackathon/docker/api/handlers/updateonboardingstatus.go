package handlers

import (
	"context"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// UpdateOnboardingStatusRequest represents the request structure for updating onboarding status
type UpdateOnboardingStatusRequest struct {
	StripeConnectAccountID string `json:"stripe_connect_account_id" binding:"required"`
}

// UpdateOnboardingStatusResponse represents the response after updating onboarding status
type UpdateOnboardingStatusResponse struct {
	AccountID              int    `json:"account_id"`
	ParentID               int    `json:"parent_id"`
	StripeConnectAccountID string `json:"stripe_connect_account_id"`
	OnboardingComplete     bool   `json:"onboarding_complete"`
	Message                string `json:"message"`
}

// UpdateOnboardingStatus marks a Stripe Connect account as onboarding complete
func UpdateOnboardingStatus(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req UpdateOnboardingStatusRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Validate stripe_connect_account_id format (should start with "acct_")
		if !strings.HasPrefix(req.StripeConnectAccountID, "acct_") {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid Stripe account ID format. Should start with 'acct_'",
			})
			return
		}

		// Check if account exists and get current status
		checkQuery := `
			SELECT account_id, parent_id, onboarding_complete 
			FROM payment_accounts 
			WHERE stripe_connect_account_id = $1
		`

		var accountID int
		var parentID int
		var currentStatus bool

		err := db.QueryRow(context.Background(), checkQuery, req.StripeConnectAccountID).Scan(
			&accountID, &parentID, &currentStatus,
		)
		if err != nil {
			if err.Error() == "no rows in result set" {
				c.JSON(http.StatusNotFound, gin.H{
					"error": "Stripe account not found",
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}

		// Check if already completed
		if currentStatus {
			c.JSON(http.StatusOK, UpdateOnboardingStatusResponse{
				AccountID:              accountID,
				ParentID:               parentID,
				StripeConnectAccountID: req.StripeConnectAccountID,
				OnboardingComplete:     true,
				Message:                "Onboarding was already complete",
			})
			return
		}

		// Update onboarding status to complete
		updateQuery := `
			UPDATE payment_accounts 
			SET onboarding_complete = true 
			WHERE stripe_connect_account_id = $1
			RETURNING account_id, parent_id
		`

		var updatedAccountID int
		var updatedParentID int

		err = db.QueryRow(context.Background(), updateQuery, req.StripeConnectAccountID).Scan(
			&updatedAccountID, &updatedParentID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update onboarding status",
			})
			return
		}

		// Return success response
		response := UpdateOnboardingStatusResponse{
			AccountID:              updatedAccountID,
			ParentID:               updatedParentID,
			StripeConnectAccountID: req.StripeConnectAccountID,
			OnboardingComplete:     true,
			Message:                "Onboarding completed successfully. Account can now receive payments.",
		}

		c.JSON(http.StatusOK, response)
	}
}
