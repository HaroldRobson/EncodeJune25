package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Event represents the event data structure
type Event struct {
	EventID                int       `json:"event_id"`
	ChildID                int       `json:"child_id"`
	EventName              string    `json:"event_name"`
	ExpiresAt              time.Time `json:"expires_at"`
	CreatedAt              time.Time `json:"created_at"`
	EventMessage           *string   `json:"event_message"`
	VideosEnabled          bool      `json:"videos_enabled"`
	PhotoAddress           *string   `json:"photo_address"`
	ChildName              string    `json:"child_name"`
	StripeConnectAccountID *string   `json:"stripe_connect_account_id"`
	OnboardingComplete     bool      `json:"onboarding_complete"`
}

// EventRequest represents the request structure for event operations
type EventRequest struct {
	EventID int `json:"event_id" binding:"required"`
}

// requestEvent returns event information for the donations page
func RequestEvent(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req EventRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Query to get event information with child name
		query := `
			SELECT 
	e.event_id,
	e.child_id,
	e.event_name,
	e.expires_at,
	e.created_at,
	e.event_message,
	e.videos_enabled,
	e.photo_address,
	c.child_name,
	pa.stripe_connect_account_id,
	pa.onboarding_complete
FROM events e
JOIN children c ON e.child_id = c.child_id
JOIN parents p ON c.parent_id = p.parent_id
LEFT JOIN payment_accounts pa ON p.parent_id = pa.parent_id
WHERE e.event_id = $1	`

		var event Event
		err := db.QueryRow(context.Background(), query, req.EventID).Scan(
			&event.EventID,
			&event.ChildID,
			&event.EventName,
			&event.ExpiresAt,
			&event.CreatedAt,
			&event.EventMessage,
			&event.VideosEnabled,
			&event.PhotoAddress,
			&event.ChildName,
			// ADD THESE:
			&event.StripeConnectAccountID,
			&event.OnboardingComplete,
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
		if time.Now().After(event.ExpiresAt) {
			c.JSON(http.StatusGone, gin.H{
				"error":      "This event has expired",
				"expired_at": event.ExpiresAt,
			})
			return
		}

		c.JSON(http.StatusOK, event)
	}
}
