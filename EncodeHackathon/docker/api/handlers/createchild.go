package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// CreateChildRequest represents the request structure for creating a child
type CreateChildRequest struct {
	ParentID  int    `json:"parent_id" binding:"required"`
	ChildName string `json:"child_name" binding:"required"`
	DOB       string `json:"dob" binding:"required"` // Format: "2017-07-15"
	Email     string `json:"email" binding:"required,email"`
}

// CreateChildResponse represents the response after creating a child
type CreateChildResponse struct {
	ChildID   int    `json:"child_id"`
	ChildName string `json:"child_name"`
	Message   string `json:"message"`
}

// CreateChild adds a new child to a parent's account
func CreateChild(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req CreateChildRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Parse date of birth
		dob, err := time.Parse("2006-01-02", req.DOB)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Invalid date format. Use YYYY-MM-DD (e.g., 2017-07-15)",
			})
			return
		}

		// Validate DOB is not in the future
		if dob.After(time.Now()) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Date of birth cannot be in the future",
			})
			return
		}

		// Validate DOB is reasonable (not more than 18 years ago for new children)
		eighteenYearsAgo := time.Now().AddDate(-18, 0, 0)
		if dob.Before(eighteenYearsAgo) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Child must be under 18 years old",
			})
			return
		}

		// Calculate ISA expiry (18th birthday)
		isaExpiry := dob.AddDate(18, 0, 0)

		// Verify parent exists
		parentCheckQuery := `SELECT parent_id FROM parents WHERE parent_id = $1`
		var parentExists int
		err = db.QueryRow(context.Background(), parentCheckQuery, req.ParentID).Scan(&parentExists)
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

		// Check if child with same email already exists
		emailCheckQuery := `SELECT child_id FROM children WHERE email = $1`
		var existingChildID int
		err = db.QueryRow(context.Background(), emailCheckQuery, req.Email).Scan(&existingChildID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "A child with this email already exists",
			})
			return
		}

		// Insert new child
		insertQuery := `
			INSERT INTO children (DOB, parent_id, email, isa_expiry, child_name)
			VALUES ($1, $2, $3, $4, $5)
			RETURNING child_id, created_at
		`

		var childID int
		var createdAt time.Time

		err = db.QueryRow(context.Background(), insertQuery,
			dob,
			req.ParentID,
			req.Email,
			isaExpiry,
			req.ChildName,
		).Scan(&childID, &createdAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to create child",
			})
			return
		}

		// Return success response
		response := CreateChildResponse{
			ChildID:   childID,
			ChildName: req.ChildName,
			Message:   "Child created successfully",
		}

		c.JSON(http.StatusCreated, response)
	}
}
