package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path"
	"strings"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/blockblob"
	"github.com/joho/godotenv"
)

// Azure Storage configuration
var (
	mongoURI      string
	accountName   string
	accountKey    string
	containerName string
)

func init() {
	if os.Getenv("ENV") != "production" {
		err := godotenv.Load()
		if err != nil {
			log.Println("Warning: .env file not loaded, using system environment variables")
		}
	}

	accountName = os.Getenv("AZURE_STORAGE_ACCOUNT")
	accountKey = os.Getenv("AZURE_STORAGE_KEY")
	containerName = os.Getenv("AZURE_STORAGE_CONTAINER")
}

func UploadHandler(w http.ResponseWriter, r *http.Request) {
	// Limit request size
	r.Body = http.MaxBytesReader(w, r.Body, 10<<20) // 10MB max

	if err := r.ParseMultipartForm(10 << 20); err != nil {
		http.Error(w, "File too big", http.StatusBadRequest)
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Error retrieving the file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Upload to Azure
	url, err := UploadToAzureBlob(file, handler.Filename)
	if err != nil {
		http.Error(w, "Azure upload failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "Uploaded successfully! File URL: %s", url)

	// Return success response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "save image successfully",
		"link":    url,
	})
}

func UploadToAzureBlob(file io.Reader, filename string) (string, error) {
	cred, err := azblob.NewSharedKeyCredential(accountName, accountKey)
	if err != nil {
		return "", err
	}

	serviceClient, err := azblob.NewClientWithSharedKeyCredential(
		fmt.Sprintf("https://%s.blob.core.windows.net/", accountName),
		cred, nil)
	if err != nil {
		return "", err
	}

	containerClient := serviceClient.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlockBlobClient(filename)
	_, err = blobClient.UploadStream(context.Background(), file, &blockblob.UploadStreamOptions{
		BlockSize:   4 * 1024 * 1024,
		Concurrency: 1,
	})

	if err != nil {
		return "", err
	}

	// Make URL publicly accessible (if container is public)
	blobURL := fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s",
		accountName, containerName, filename)

	return blobURL, nil
}

func DeleteByURL(blobURL string) error {
	// Validate the URL is from your Azure Blob Storage
	if !strings.Contains(blobURL, fmt.Sprintf("%s.blob.core.windows.net/%s", accountName, containerName)) {
		return fmt.Errorf("invalid URL: not part of Azure Blob container")
	}

	// Extract the blob name from the URL
	parsedURL, err := url.Parse(blobURL)
	if err != nil {
		return fmt.Errorf("invalid URL format: %w", err)
	}
	blobName := path.Base(parsedURL.Path)

	// Delete the blob
	return DeleteFromAzureBlob(blobName)
}

// DeleteFromAzureBlob deletes a blob from Azure Blob Storage
func DeleteFromAzureBlob(blobName string) error {
	cred, err := azblob.NewSharedKeyCredential(accountName, accountKey)
	if err != nil {
		return err
	}

	serviceClient, err := azblob.NewClientWithSharedKeyCredential(
		fmt.Sprintf("https://%s.blob.core.windows.net/", accountName),
		cred, nil)
	if err != nil {
		return err
	}

	containerClient := serviceClient.ServiceClient().NewContainerClient(containerName)
	blobClient := containerClient.NewBlobClient(blobName)

	_, err = blobClient.Delete(context.Background(), nil)
	return err
}
