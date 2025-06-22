package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// VideoUploadResponse represents the response after uploading a video
type VideoUploadResponse struct {
	VideoURL string `json:"video_url"`
	Message  string `json:"message"`
}

// UploadVideo handles video file uploads
func UploadVideo(c *gin.Context) {
	// Get the uploaded file
	file, err := c.FormFile("video")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No video file provided",
		})
		return
	}

	// Validate file size (50MB max)
	maxSize := int64(50 * 1024 * 1024) // 50MB in bytes
	if file.Size > maxSize {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "File too large. Maximum size is 50MB",
		})
		return
	}

	// Validate file extension
	allowedExtensions := []string{".mp4", ".mov", ".avi", ".webm"}
	fileExt := strings.ToLower(filepath.Ext(file.Filename))

	isValidExt := false
	for _, ext := range allowedExtensions {
		if fileExt == ext {
			isValidExt = true
			break
		}
	}

	if !isValidExt {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid file type. Allowed: .mp4, .mov, .avi, .webm",
		})
		return
	}

	// Create uploads directory if it doesn't exist
	uploadDir := "/var/uploads/videos"
	if err := os.MkdirAll(uploadDir, 0o755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create upload directory",
		})
		return
	}

	// Generate unique filename
	// Format: timestamp_originalname.ext
	timestamp := time.Now().Unix()
	filename := fmt.Sprintf("%d_%s", timestamp, file.Filename)
	filepath := filepath.Join(uploadDir, filename)

	// Save the file
	if err := c.SaveUploadedFile(file, filepath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to save video file",
		})
		return
	}

	// Generate the public URL
	// This assumes your server is accessible at the host/port
	videoURL := fmt.Sprintf("http://localhost:8080/api/videos/%s", filename)

	response := VideoUploadResponse{
		VideoURL: videoURL,
		Message:  "Video uploaded successfully",
	}

	c.JSON(http.StatusCreated, response)
}

// ServeVideo serves video files from the uploads directory
func ServeVideo(c *gin.Context) {
	filename := c.Param("filename")

	// Validate filename (prevent path traversal attacks)
	if strings.Contains(filename, "..") || strings.Contains(filename, "/") {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid filename",
		})
		return
	}

	filepath := filepath.Join("/var/uploads/videos", filename)

	// Check if file exists
	if _, err := os.Stat(filepath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Video not found",
		})
		return
	}

	// Serve the file
	// Gin automatically sets the correct Content-Type based on file extension
	c.File(filepath)
}
