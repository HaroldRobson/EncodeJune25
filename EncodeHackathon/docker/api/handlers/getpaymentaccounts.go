package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// GetPaymentAccountsRequest represents the request structure for getting payment account status
type GetPaymentAccountsRequest struct {
	ParentID int `json:"parent_id" binding:"required"`
}

// PaymentAccountInfo represents payment account information
type PaymentAccountInfo struct {
	AccountID              int       `json:"account_id"`
	StripeConnectAccountID string    `json:"stripe_connect_account_id"`
	OnboardingComplete     bool      `json:"onboarding_complete"`
	CreatedAt              time.Time `json:"created_at"`
}

// GetPaymentAccountsResponse represents the response with payment account status
type GetPaymentAccountsResponse struct {
	ParentID       int                 `json:"parent_id"`
	HasAccount     bool                `json:"has_account"`
	PaymentAccount *PaymentAccountInfo `json:"payment_account"`
	Status         string              `json:"status"`
	Message        string              `json:"message"`
}

// GetPaymentAccounts retrieves payment account status for a parent
func GetPaymentAccounts(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req GetPaymentAccountsRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
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

		// Query payment account for this parent
		accountQuery := `
			SELECT account_id, stripe_connect_account_id, onboarding_complete, created_at
			FROM payment_accounts 
			WHERE parent_id = $1
		`

		var account PaymentAccountInfo
		err = db.QueryRow(context.Background(), accountQuery, req.ParentID).Scan(
			&account.AccountID,
			&account.StripeConnectAccountID,
			&account.OnboardingComplete,
			&account.CreatedAt,
		)

		// Build response based on account status
		var response GetPaymentAccountsResponse
		response.ParentID = req.ParentID

		if err != nil {
			if err.Error() == "no rows in result set" {
				// No payment account exists
				response.HasAccount = false
				response.PaymentAccount = nil
				response.Status = "no_account"
				response.Message = "No payment account set up. Create a Stripe account to start receiving donations."
			} else {
				// Database error
				c.JSON(http.StatusInternalServerError, gin.H{
					"error": "Failed to query payment account",
				})
				return
			}
		} else {
			// Payment account exists
			response.HasAccount = true
			response.PaymentAccount = &account

			if account.OnboardingComplete {
				response.Status = "ready"
				response.Message = "Payment account is ready to receive donations."
			} else {
				response.Status = "pending_onboarding"
				response.Message = "Complete Stripe onboarding to start receiving donations."
			}
		}

		c.JSON(http.StatusOK, response)
	}
}
