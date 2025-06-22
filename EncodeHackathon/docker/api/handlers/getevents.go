package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// EventSummary represents event data for listing view
type EventSummary struct {
	EventID       int       `json:"event_id"`
	ChildID       int       `json:"child_id"`
	EventName     string    `json:"event_name"`
	ExpiresAt     time.Time `json:"expires_at"`
	CreatedAt     time.Time `json:"created_at"`
	EventMessage  *string   `json:"event_message"`
	VideosEnabled bool      `json:"videos_enabled"`
	PhotoAddress  *string   `json:"photo_address"`
	ChildName     string    `json:"child_name"`
	IsExpired     bool      `json:"is_expired"`
	DaysRemaining int       `json:"days_remaining"`
}

// GetEventsRequest represents the request structure for getting events
type GetEventsRequest struct {
	ParentID int `json:"parent_id" binding:"required"`
}

// GetEventsResponse represents the response with list of events
type GetEventsResponse struct {
	Events []EventSummary `json:"events"`
	Count  int            `json:"count"`
}

// GetEvents returns all events for a parent's children
func GetEvents(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req GetEventsRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Query to get all events for the parent's children
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
				c.child_name
			FROM events e
			JOIN children c ON e.child_id = c.child_id
			WHERE c.parent_id = $1
			ORDER BY e.expires_at ASC, e.created_at DESC
		`

		rows, err := db.Query(context.Background(), query, req.ParentID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}
		defer rows.Close()

		var events []EventSummary
		now := time.Now()

		for rows.Next() {
			var event EventSummary
			err := rows.Scan(
				&event.EventID,
				&event.ChildID,
				&event.EventName,
				&event.ExpiresAt,
				&event.CreatedAt,
				&event.EventMessage,
				&event.VideosEnabled,
				&event.PhotoAddress,
				&event.ChildName,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"error": "Failed to scan event data",
				})
				return
			}

			// Calculate expiry status and days remaining
			event.IsExpired = now.After(event.ExpiresAt)
			if !event.IsExpired {
				duration := event.ExpiresAt.Sub(now)
				event.DaysRemaining = int(duration.Hours() / 24)
			} else {
				event.DaysRemaining = 0
			}

			events = append(events, event)
		}

		// Check for errors from iterating over rows
		if err := rows.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Error processing event data",
			})
			return
		}

		// Return response
		response := GetEventsResponse{
			Events: events,
			Count:  len(events),
		}

		c.JSON(http.StatusOK, response)
	}
}
