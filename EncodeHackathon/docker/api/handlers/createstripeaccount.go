package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SaveStripeAccountRequest represents the request structure for saving a Stripe account ID
type SaveStripeAccountRequest struct {
	ParentID               int    `json:"parent_id" binding:"required"`
	StripeConnectAccountID string `json:"stripe_connect_account_id" binding:"required"`
}

// SaveStripeAccountResponse represents the response after saving a Stripe account
type SaveStripeAccountResponse struct {
	AccountID              int    `json:"account_id"`
	ParentID               int    `json:"parent_id"`
	StripeConnectAccountID string `json:"stripe_connect_account_id"`
	OnboardingComplete     bool   `json:"onboarding_complete"`
	Message                string `json:"message"`
}

// SaveStripeAccount saves a Stripe Connect account ID that was created client-side
func SaveStripeAccount(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req SaveStripeAccountRequest

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

		// Verify parent exists
		parentCheckQuery := `SELECT parent_id FROM parents WHERE parent_id = $1`
		var parentExists int
		err := db.QueryRow(context.Background(), parentCheckQuery, req.ParentID).Scan(&parentExists)
		if err != nil {
			if err.Error() == "no rows in result set" {
				c.JSON(http.StatusNotFound, gin.H{
					"error": "Parent not found",
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}

		// Check if parent already has a Stripe account
		existingAccountQuery := `SELECT account_id FROM payment_accounts WHERE parent_id = $1`
		var existingAccountID int
		err = db.QueryRow(context.Background(), existingAccountQuery, req.ParentID).Scan(&existingAccountID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "Parent already has a Stripe account",
			})
			return
		}

		// Check if this Stripe account ID is already used by another parent
		duplicateStripeQuery := `SELECT account_id FROM payment_accounts WHERE stripe_connect_account_id = $1`
		var duplicateAccountID int
		err = db.QueryRow(context.Background(), duplicateStripeQuery, req.StripeConnectAccountID).Scan(&duplicateAccountID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "This Stripe account is already linked to another parent",
			})
			return
		}

		// Insert payment account record
		insertQuery := `
			INSERT INTO payment_accounts (parent_id, stripe_connect_account_id, onboarding_complete)
			VALUES ($1, $2, $3)
			RETURNING account_id, created_at
		`

		var accountID int
		var createdAt time.Time

		err = db.QueryRow(context.Background(), insertQuery,
			req.ParentID,
			req.StripeConnectAccountID,
			false, // onboarding starts as incomplete - frontend will update via webhook
		).Scan(&accountID, &createdAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to save payment account",
			})
			return
		}

		// Return success response
		response := SaveStripeAccountResponse{
			AccountID:              accountID,
			ParentID:               req.ParentID,
			StripeConnectAccountID: req.StripeConnectAccountID,
			OnboardingComplete:     false,
			Message:                "Stripe account linked successfully. Complete onboarding to start receiving payments.",
		}

		c.JSON(http.StatusCreated, response)
	}
}
