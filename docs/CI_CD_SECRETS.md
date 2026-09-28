# CI/CD Secrets Setup

This document outlines the GitHub Secrets required for the automated CI/CD workflows.
These secrets must be configured in your GitHub repository under `Settings → Secrets and variables → Actions`.

## Required GitHub Secrets for CI/CD

### 1. `SFDX_AUTH_URL` (for `deploy.yml` - Main Branch Deployment)

| Secret Name | Value | How to Get |
|---|---|---|
| `SFDX_AUTH_URL` | The `force://` auth URL for your persistent Dev Sandbox (e.g., `demo-scratch`) | On your VM: `SF_TEMP_SHOW_SECRETS=true sf org display --target-org <YOUR_DEV_ORG_ALIAS> --verbose` (look for the `sfdxAuthUrl` field) |

**Purpose:** This secret is used by the `deploy.yml` workflow to authenticate and deploy the `main` branch code to your designated Dev Sandbox. This ensures your integration environment is always up-to-date with the latest `main` branch.

### 2. JWT Authentication Secrets (for `ci.yml` - PR Validation with Ephemeral Scratch Orgs)

To enable the `ci.yml` workflow to create and manage ephemeral scratch orgs, you need to set up JWT-based authentication for your Dev Hub.

| Secret Name | Value | How to Get |
|---|---|---|
| `SF_JWT_CLIENT_ID` | The Consumer Key from your Connected App in Salesforce | Create a Connected App in your Dev Hub org. |
| `SF_JWT_KEY` | The private key content from your JWT server key file (.pem file) | Generate a self-signed certificate and key. |
| `SF_DEV_HUB_USERNAME` | The username of your Salesforce Dev Hub org | Your Dev Hub username (e.g., `maria.robbins@chickentightslabs.com.crmsfdevorg`) |

**Prerequisites:**
*   **Enable Dev Hub:** In your Salesforce Dev Hub org (`chickentightslabs`), navigate to `Setup -> Dev Hub` and ensure it is enabled.
*   **Create Connected App:** Follow Salesforce documentation to create a Connected App that allows JWT bearer flow. Ensure it's configured for `oauth_connection_type=jwt-bearer` and the user specified in `SF_DEV_HUB_USERNAME` has access.
*   **Generate Certificate and Key:** Create a self-signed certificate and key pair. The `.pem` file content goes into `SF_JWT_KEY`.

## Workflow Overview

1.  **`ci.yml` (PR Validation):**
    *   **Trigger:** `pull_request` events to `main` or `master` branches.
    *   **Action:** Creates a new, ephemeral scratch org for each PR, deploys the feature branch code, runs *all* Apex tests (`RunAllTests`), and then deletes the scratch org. The status is reported back to the GitHub PR.
    *   **Requires:** `SF_JWT_CLIENT_ID`, `SF_JWT_KEY`, `SF_DEV_HUB_USERNAME` secrets.

2.  **`deploy.yml` (Main Branch Deployment):**
    *   **Trigger:** `push` events to `main` or `master` branches, or `workflow_dispatch` (manual trigger).
    *   **Action:** Deploys the latest `main` branch code to your designated persistent Dev Sandbox (e.g., `demo-scratch`), and runs `RunRelevantTests`.
    *   **Requires:** `SFDX_AUTH_URL` secret.

This setup ensures isolated validation for feature work and continuous integration for the main development line.
