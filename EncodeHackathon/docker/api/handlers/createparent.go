package handlers

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// CreateParentRequest represents the request structure for creating a parent
type CreateParentRequest struct {
	ParentEmail string `json:"parent_email" binding:"required,email"`
	Auth0ID     string `json:"auth0_id" binding:"required"`
}

// CreateParentResponse represents the response after creating a parent
type CreateParentResponse struct {
	ParentID    int    `json:"parent_id"`
	ParentEmail string `json:"parent_email"`
	Auth0ID     string `json:"auth0_id"`
	Message     string `json:"message"`
}

// CreateParent adds a new parent account to the system
func CreateParent(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req CreateParentRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Validate auth0_id format (should start with "auth0|")
		if !strings.HasPrefix(req.Auth0ID, "auth0|") {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid auth0_id format. Should start with 'auth0|'",
			})
			return
		}

		// Check if parent with same auth0_id already exists
		auth0CheckQuery := `SELECT parent_id FROM parents WHERE auth0_id = $1`
		var existingParentID int
		err := db.QueryRow(context.Background(), auth0CheckQuery, req.Auth0ID).Scan(&existingParentID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "A parent with this Auth0 ID already exists",
			})
			return
		}

		// Check if parent with same email already exists
		emailCheckQuery := `SELECT parent_id FROM parents WHERE parent_email = $1`
		var existingEmailParentID int
		err = db.QueryRow(context.Background(), emailCheckQuery, req.ParentEmail).Scan(&existingEmailParentID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "A parent with this email already exists",
			})
			return
		}

		// Insert new parent
		insertQuery := `
			INSERT INTO parents (parent_email, auth0_id)
			VALUES ($1, $2)
			RETURNING parent_id, created_at
		`

		var parentID int
		var createdAt time.Time

		err = db.QueryRow(context.Background(), insertQuery,
			req.ParentEmail,
			req.Auth0ID,
		).Scan(&parentID, &createdAt)
		if err != nil {
			// Debug logging - remove this after fixing
			fmt.Printf("Database error: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create parent account",
			})
			return
		}

		// Return success response
		response := CreateParentResponse{
			ParentID:    parentID,
			ParentEmail: req.ParentEmail,
			Auth0ID:     req.Auth0ID,
			Message:     "Parent account created successfully",
		}

		c.JSON(http.StatusCreated, response)
	}
}
