package com.acme.modres.util;

import com.azure.core.exception.AzureException;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.storage.blob.BlobClient;
import com.azure.storage.blob.BlobContainerClient;
import com.azure.storage.blob.BlobServiceClient;
import com.azure.storage.blob.BlobServiceClientBuilder;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Azure Blob Storage client utility.
 * Lazily initializes the storage client on first use, using Managed Identity
 * via DefaultAzureCredential. The storage endpoint and container name are read
 * from environment variables.
 */
public final class BlobStorageClient {

  private static BlobStorageClient instance;

  private final BlobContainerClient containerClient;

  private BlobStorageClient() {
    String endpoint = System.getenv("AZURE_STORAGE_ENDPOINT");
    String containerName = System.getenv("AZURE_STORAGE_CONTAINER");
    if (endpoint == null || endpoint.trim().isEmpty()) {
      throw new IllegalStateException("AZURE_STORAGE_ENDPOINT is not set");
    }
    if (containerName == null || containerName.trim().isEmpty()) {
      throw new IllegalStateException("AZURE_STORAGE_CONTAINER is not set");
    }

    BlobServiceClient serviceClient = new BlobServiceClientBuilder()
        .endpoint(endpoint)
        .credential(new DefaultAzureCredentialBuilder().build())
        .buildClient();

    this.containerClient = serviceClient.getBlobContainerClient(containerName);
  }

  public static synchronized BlobStorageClient getInstance() {
    if (instance == null) {
      instance = new BlobStorageClient();
    }
    return instance;
  }

  public void uploadBlob(String blobName, byte[] data) throws IOException {
    try {
      BlobClient blobClient = containerClient.getBlobClient(blobName);
      blobClient.upload(new ByteArrayInputStream(data), data.length, true);
    } catch (AzureException e) {
      throw new IOException("Failed to upload blob: " + blobName, e);
    }
  }

  public byte[] downloadBlob(String blobName) throws IOException {
    try {
      BlobClient blobClient = containerClient.getBlobClient(blobName);
      ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
      blobClient.downloadStream(outputStream);
      return outputStream.toByteArray();
    } catch (AzureException e) {
      throw new IOException("Failed to download blob: " + blobName, e);
    }
  }

  public InputStream openInputStream(String blobName) throws IOException {
    try {
      BlobClient blobClient = containerClient.getBlobClient(blobName);
      return blobClient.openInputStream();
    } catch (AzureException e) {
      throw new IOException("Failed to open blob stream: " + blobName, e);
    }
  }

  public boolean blobExists(String blobName) {
    try {
      return containerClient.getBlobClient(blobName).exists();
    } catch (AzureException e) {
      return false;
    }
  }

  public void deleteBlob(String blobName) {
    try {
      containerClient.getBlobClient(blobName).deleteIfExists();
    } catch (AzureException e) {
      // Silently ignore deletion failures
    }
  }
}
