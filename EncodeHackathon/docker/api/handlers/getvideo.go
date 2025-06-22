package handlers

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
)

// GetVideo serves video files from the uploads directory
func GetVideo(c *gin.Context) {
	filename := c.Param("filename")

	// Validate filename (prevent path traversal attacks)
	if strings.Contains(filename, "..") || strings.Contains(filename, "/") || strings.Contains(filename, "\\") {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid filename",
		})
		return
	}

	// Validate file extension (only serve video files)
	allowedExtensions := []string{".mp4", ".mov", ".avi", ".webm"}
	fileExt := strings.ToLower(filepath.Ext(filename))
	isValidExt := false
	for _, ext := range allowedExtensions {
		if fileExt == ext {
			isValidExt = true
			break
		}
	}

	if !isValidExt {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid file type",
		})
		return
	}

	// Build full file path
	filePath := filepath.Join("/var/uploads/videos", filename)

	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Video not found",
		})
		return
	}

	// Set appropriate headers for video serving
	c.Header("Content-Type", "video/mp4")             // Default to mp4, browser will handle others
	c.Header("Accept-Ranges", "bytes")                // Enable video seeking
	c.Header("Cache-Control", "public, max-age=3600") // Cache for 1 hour

	// Serve the file
	c.File(filePath)
}
