package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DonationReview represents donation data for review
type DonationReview struct {
	ID           int       `json:"id"`
	Message      *string   `json:"message"`
	DonorName    string    `json:"donor_name"`
	AmountPence  int       `json:"amount_pence"`
	Approved     bool      `json:"approved"`
	EventID      int       `json:"event_id"`
	CreatedAt    time.Time `json:"created_at"`
	VideoAddress *string   `json:"video_address"`
}

// ListDonationsRequest represents the request structure for listing donations
type ListDonationsRequest struct {
	EventID int `json:"event_id" binding:"required"`
}

// ListDonationsResponse represents the response with donation statistics
type ListDonationsResponse struct {
	Donations           []DonationReview `json:"donations"`
	TotalDonations      int              `json:"total_donations"`
	ApprovedDonations   int              `json:"approved_donations"`
	PendingDonations    int              `json:"pending_donations"`
	TotalAmountPence    int              `json:"total_amount_pence"`
	ApprovedAmountPence int              `json:"approved_amount_pence"`
	EventName           string           `json:"event_name"`
	ChildName           string           `json:"child_name"`
}

// ListDonations returns all donations for an event (for parent review)
func ListDonations(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req ListDonationsRequest

		// Bind JSON request body
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "Invalid request format",
				"details": err.Error(),
			})
			return
		}

		// Verify event exists and get event details
		eventQuery := `
			SELECT 
				e.event_name,
				c.child_name
			FROM events e
			JOIN children c ON e.child_id = c.child_id
			WHERE e.event_id = $1
		`

		var eventName, childName string
		err := db.QueryRow(context.Background(), eventQuery, req.EventID).Scan(&eventName, &childName)
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

		// Query to get all donations for the event
		donationsQuery := `
			SELECT 
				id,
				message,
				donor_name,
				amount_pence,
				approved,
				event_id,
				created_at,
				video_address
			FROM donations
			WHERE event_id = $1
			ORDER BY created_at DESC
		`

		rows, err := db.Query(context.Background(), donationsQuery, req.EventID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Failed to query donations",
			})
			return
		}
		defer rows.Close()

		var donations []DonationReview
		var totalAmount, approvedAmount int
		var approvedCount, pendingCount int

		for rows.Next() {
			var donation DonationReview
			err := rows.Scan(
				&donation.ID,
				&donation.Message,
				&donation.DonorName,
				&donation.AmountPence,
				&donation.Approved,
				&donation.EventID,
				&donation.CreatedAt,
				&donation.VideoAddress,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{
					"error": "Failed to scan donation data",
				})
				return
			}

			donations = append(donations, donation)
			totalAmount += donation.AmountPence

			if donation.Approved {
				approvedCount++
				approvedAmount += donation.AmountPence
			} else {
				pendingCount++
			}
		}

		// Check for errors from iterating over rows
		if err := rows.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Error processing donation data",
			})
			return
		}

		// Return response with statistics
		response := ListDonationsResponse{
			Donations:           donations,
			TotalDonations:      len(donations),
			ApprovedDonations:   approvedCount,
			PendingDonations:    pendingCount,
			TotalAmountPence:    totalAmount,
			ApprovedAmountPence: approvedAmount,
			EventName:           eventName,
			ChildName:           childName,
		}

		c.JSON(http.StatusOK, response)
	}
}
