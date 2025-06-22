package main

import (
	"log"
	"os"

	"aletterahead-api/handlers"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	// Initialize database
	db, err := InitDB()
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Initialize router
	r := gin.Default()

	// Add CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "OK",
			"service": "aletterahead-api",
		})
	})

	// API routes
	api := r.Group("/api")
	{
		// Events routes
		api.POST("/events/request", handlers.RequestEvent(db))
		api.POST("/events/list", handlers.GetEvents(db))
		api.POST("/events/create", handlers.CreateEvent(db))
		api.POST("/donations/create", handlers.CreateDonation(db))
		api.POST("/donations/list", handlers.ListDonations(db))
		api.POST("/donations/approve", handlers.ApproveDonation(db))
		api.POST("/uploads/video", handlers.UploadVideo)
		api.POST("/children/list", handlers.GetChildren(db))
		api.POST("/children/create", handlers.CreateChild(db))
		api.POST("/parents/create", handlers.CreateParent(db))
		api.POST("/parents/get", handlers.GetParent(db))
		api.POST("/payments/save-account", handlers.SaveStripeAccount(db))
		api.POST("/payments/onboarding-complete", handlers.UpdateOnboardingStatus(db))
		api.POST("/payments/status", handlers.GetPaymentAccounts(db))
		api.GET("/videos/:filename", handlers.GetVideo)
		// Future endpoints will follow this pattern:
		// api.POST("/donations/create", createDonation(db))
		// api.POST("/donations/list", listDonations(db))
		// api.POST("/children/create", createChild(db))
		// etc.
	}

	// Get port from env or default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 Server starting on port %s", port)
	r.Run(":" + port)
}
