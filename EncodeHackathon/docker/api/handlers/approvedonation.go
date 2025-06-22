package handlers

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ApproveDonationRequest represents the request structure for approving/rejecting donations
type ApproveDonationRequest struct {
	DonationID int  `json:"donation_id" binding:"required"`
	Approved   bool `json:"approved"` // Remove required tag for boolean
}

// ApproveDonationResponse represents the response after approval action
type ApproveDonationResponse struct {
	DonationID int    `json:"donation_id"`
	Approved   bool   `json:"approved"`
	DonorName  string `json:"donor_name"`
	Message    string `json:"message"`
}

// ApproveDonation approves or rejects a donation
func ApproveDonation(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req ApproveDonationRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// First, verify the donation exists and get its details
		verifyQuery := `
			SELECT 
				d.id,
				d.donor_name,
				d.approved,
				d.event_id,
				e.event_name,
				c.child_name
			FROM donations d
			JOIN events e ON d.event_id = e.event_id
			JOIN children c ON e.child_id = c.child_id
			WHERE d.id = $1
		`

		var donationID int
		var donorName string
		var currentApproval bool
		var eventID int
		var eventName string
		var childName string

		err := db.QueryRow(context.Background(), verifyQuery, req.DonationID).Scan(
			&donationID,
			&donorName,
			&currentApproval,
			&eventID,
			&eventName,
			&childName,
		)
		if err != nil {
			if err.Error() == "no rows in result set" {
				c.JSON(http.StatusNotFound, gin.H{
					"error": "Donation not found",
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Database query failed",
			})
			return
		}

		// Check if the approval status is already what was requested
		if currentApproval == req.Approved {
			status := "approved"
			if !req.Approved {
				status = "rejected"
			}
			c.JSON(http.StatusOK, gin.H{
				"message":     "Donation is already " + status,
				"donation_id": req.DonationID,
				"approved":    currentApproval,
			})
			return
		}

		// Update the approval status (remove updated_at since column doesn't exist)
		updateQuery := `
			UPDATE donations 
			SET approved = $1
			WHERE id = $2
		`

		_, err = db.Exec(context.Background(), updateQuery, req.Approved, req.DonationID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to update donation status",
			})
			return
		}

		// Determine response message
		action := "approved"
		if !req.Approved {
			action = "rejected"
		}

		// Return success response
		response := ApproveDonationResponse{
			DonationID: req.DonationID,
			Approved:   req.Approved,
			DonorName:  donorName,
			Message:    "Donation " + action + " successfully",
		}

		c.JSON(http.StatusOK, response)
	}
}
