package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// CreateEventRequest represents the request structure for creating an event
type CreateEventRequest struct {
	ChildID       int     `json:"child_id" binding:"required"`
	EventName     string  `json:"event_name" binding:"required"`
	ExpiresAt     string  `json:"expires_at" binding:"required"` // Format: "2025-07-15"
	EventMessage  *string `json:"event_message"`
	VideosEnabled bool    `json:"videos_enabled"`
	PhotoAddress  *string `json:"photo_address"`
}

// CreateEventResponse represents the response after creating an event
type CreateEventResponse struct {
	EventID   int    `json:"event_id"`
	EventName string `json:"event_name"`
	ChildName string `json:"child_name"`
	Message   string `json:"message"`
}

// CreateEvent creates a new birthday event for a child
func CreateEvent(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req CreateEventRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Parse expiry date
		expiresAt, err := time.Parse("2006-01-02", req.ExpiresAt)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid date format. Use YYYY-MM-DD (e.g., 2025-07-15)",
			})
			return
		}

		// Validate expiry date is in the future
		if expiresAt.Before(time.Now()) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Expiry date must be in the future",
			})
			return
		}

		// Validate expiry date is not too far in the future (max 2 years)
		twoYearsFromNow := time.Now().AddDate(2, 0, 0)
		if expiresAt.After(twoYearsFromNow) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Expiry date cannot be more than 2 years in the future",
			})
			return
		}

		// Verify child exists and get child details
		childQuery := `
			SELECT 
				c.child_id,
				c.child_name,
				c.parent_id
			FROM children c
			WHERE c.child_id = $1
		`

		var childID int
		var childName string
		var parentID int

		err = db.QueryRow(context.Background(), childQuery, req.ChildID).Scan(
			&childID,
			&childName,
			&parentID,
		)
		if err != nil {
			if err.Error() == "no rows in result set" {
				c.JSON(http.StatusNotFound, gin.H{
					"error": "Child not found",
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}

		// Check if child already has an active event with the same name
		duplicateCheckQuery := `
			SELECT event_id 
			FROM events 
			WHERE child_id = $1 
			AND event_name = $2 
			AND expires_at > NOW()
		`

		var existingEventID int
		err = db.QueryRow(context.Background(), duplicateCheckQuery, req.ChildID, req.EventName).Scan(&existingEventID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "An active event with this name already exists for this child",
			})
			return
		}

		// Insert new event
		insertQuery := `
			INSERT INTO events (child_id, event_name, expires_at, event_message, videos_enabled, photo_address)
			VALUES ($1, $2, $3, $4, $5, $6)
			RETURNING event_id, created_at
		`

		var eventID int
		var createdAt time.Time

		err = db.QueryRow(context.Background(), insertQuery,
			req.ChildID,
			req.EventName,
			expiresAt,
			req.EventMessage,
			req.VideosEnabled,
			req.PhotoAddress,
		).Scan(&eventID, &createdAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create event",
			})
			return
		}

		// Return success response
		response := CreateEventResponse{
			EventID:   eventID,
			EventName: req.EventName,
			ChildName: childName,
			Message:   "Event created successfully",
		}

		c.JSON(http.StatusCreated, response)
	}
}
