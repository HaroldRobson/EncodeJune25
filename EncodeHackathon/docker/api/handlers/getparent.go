package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// GetParentRequest represents the request structure for getting a parent
type GetParentRequest struct {
	Auth0ID string `json:"auth0_id" binding:"required"`
}

// GetParentResponse represents the response with parent information
type GetParentResponse struct {
	ParentID         int       `json:"parent_id"`
	ParentEmail      string    `json:"parent_email"`
	Auth0ID          string    `json:"auth0_id"`
	StripeCustomerID *string   `json:"stripe_customer_id"`
	CreatedAt        time.Time `json:"created_at"`
}

// GetParent retrieves a parent's profile information by Auth0 ID
func GetParent(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req GetParentRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Validate auth0_id format (should start with "auth0|")
		if req.Auth0ID == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Auth0 ID is required",
			})
			return
		}

		// Query parent by auth0_id
		query := `
			SELECT parent_id, parent_email, auth0_id, stripe_customer_id, created_at
			FROM parents 
			WHERE auth0_id = $1
		`

		var parent GetParentResponse
		var stripeCustomerID *string

		err := db.QueryRow(context.Background(), query, req.Auth0ID).Scan(
			&parent.ParentID,
			&parent.ParentEmail,
			&parent.Auth0ID,
			&stripeCustomerID,
			&parent.CreatedAt,
		)
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

		// Handle nullable stripe_customer_id
		parent.StripeCustomerID = stripeCustomerID

		// Return parent information
		c.JSON(http.StatusOK, parent)
	}
}
