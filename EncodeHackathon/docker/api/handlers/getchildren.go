package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Child represents the child data structure
type Child struct {
	ChildID   int       `json:"child_id"`
	DOB       time.Time `json:"dob"`
	ParentID  int       `json:"parent_id"`
	Email     string    `json:"email"`
	ISAExpiry time.Time `json:"isa_expiry"`
	CreatedAt time.Time `json:"created_at"`
	ChildName string    `json:"child_name"`
}

// GetChildrenRequest represents the request structure for getting children
type GetChildrenRequest struct {
	ParentID int `json:"parent_id" binding:"required"`
}

// GetChildrenResponse represents the response with list of children
type GetChildrenResponse struct {
	Children []Child `json:"children"`
	Count    int     `json:"count"`
}

// GetChildren returns all children for a parent
func GetChildren(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req GetChildrenRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Query to get all children for the parent
		query := `
			SELECT 
				child_id,
				DOB,
				parent_id,
				email,
				isa_expiry,
				created_at,
				child_name
			FROM children
			WHERE parent_id = $1
			ORDER BY child_name ASC
		`

		rows, err := db.Query(context.Background(), query, req.ParentID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}
		defer rows.Close()

		var children []Child

		for rows.Next() {
			var child Child
			err := rows.Scan(
				&child.ChildID,
				&child.DOB,
				&child.ParentID,
				&child.Email,
				&child.ISAExpiry,
				&child.CreatedAt,
				&child.ChildName,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"error": "Failed to scan child data",
				})
				return
			}
			children = append(children, child)
		}

		// Check for errors from iterating over rows
		if err := rows.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Error processing child data",
			})
			return
		}

		// Return response
		response := GetChildrenResponse{
			Children: children,
			Count:    len(children),
		}

		c.JSON(http.StatusOK, response)
	}
}
