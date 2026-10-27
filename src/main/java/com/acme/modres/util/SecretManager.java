package com.acme.modres.util;

import com.azure.core.exception.AzureException;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.security.keyvault.secrets.SecretClient;
import com.azure.security.keyvault.secrets.SecretClientBuilder;

import java.io.IOException;

/**
 * Azure Key Vault secret manager utility.
 * Lazily initializes the secret client on first use, using Managed Identity
 * via DefaultAzureCredential. The Key Vault URL and secret name are read
 * from environment variables.
 */
public final class SecretManager {

  private static SecretManager instance;

  private final SecretClient secretClient;

  private SecretManager() {
    String keyVaultUrl = System.getenv("AZURE_KEYVAULT_URL");
    if (keyVaultUrl == null || keyVaultUrl.trim().isEmpty()) {
      throw new IllegalStateException("AZURE_KEYVAULT_URL is not set");
    }

    this.secretClient = new SecretClientBuilder()
        .vaultUrl(keyVaultUrl)
        .credential(new DefaultAzureCredentialBuilder().build())
        .buildClient();
  }

  public static synchronized SecretManager getInstance() {
    if (instance == null) {
      instance = new SecretManager();
    }
    return instance;
  }

  public String getSecret(String secretName) throws IOException {
    try {
      return secretClient.getSecret(secretName).getValue();
    } catch (AzureException e) {
      throw new IOException("Failed to retrieve secret: " + secretName, e);
    }
  }
}
