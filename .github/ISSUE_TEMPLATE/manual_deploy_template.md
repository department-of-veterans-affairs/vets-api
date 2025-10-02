name: Vets-API Manual Deployment Verification and Sync
description: Checklist to verify deployments and sync environments for vets-api
title: "[Deployment] Verify and Sync vets-api Environments"

body:
  - type: markdown
    attributes:
      value: |
        ## Deployment Verification & Sync Instructions
        Follow this checklist to ensure vets-api is properly deployed to **dev**, **staging**, **prod**, and **sandbox** environments.

  - type: checkboxes
    id: verify-deployments
    attributes:
      label: Verify Deployment Status
      description: Ensure there are no deployment issues for **dev** and **staging**.
      options:
        - label: Checked vets-api-dev deployment (no issues), https://argocd.vfs.va.gov/applications/vets-api-dev?operation=false&resource=.
        - label: Checked vets-api-staging deployment (no issues), https://argocd.vfs.va.gov/applications/vets-api-staging?operation=false&resource=.
        - label: Verified deploy status(https://www.va.gov/atlas/apps/vets-api/deploy_status) matches latest vets-api commit for **dev**.
        - label: Verified deploy status matches(https://www.va.gov/atlas/apps/vets-api/deploy_status) latest vets-api commit for **staging**.

  - type: markdown
    attributes:
      value: |
        ## Sync Prod
        1. Go to **vets-api-prod**.
        2. Click **Sync**.
        3. Ensure **PRUNE** and **AUTO-CREATE NAMESPACE** are **checked** (see image reference).
        4. Click **Synchronize**.

  - type: checkboxes
    id: sync-prod
    attributes:
      label: Prod Sync
      options:
        - label: Navigated to vets-api-prod, https://argocd.vfs.va.gov/applications/vets-api-prod?operation=false&resource=.
        - label: Confirmed PRUNE and AUTO-CREATE NAMESPACE are checked.
        - label: Clicked Synchronize.

  - type: markdown
    attributes:
      value: |
        ## Sync Sandbox
        1. Navigated to vets-api-sandbox, https://argocd.vfs.va.gov/applications/vets-api-sandbox?operation=false&resource=.
        2. Click **Sync**.
        3. Ensure **PRUNE** and **AUTO-CREATE NAMESPACE** are **checked**.
        4. Click **Synchronize**.

  - type: checkboxes
    id: sync-sandbox
    attributes:
      label: Sandbox Sync
      options:
        - label: Navigated to vets-api-sandbox.
        - label: Confirmed PRUNE and AUTO-CREATE NAMESPACE are checked.
        - label: Clicked Synchronize.

  - type: textarea
    id: notes
    attributes:
      label: Notes
      description: Add any issues, errors, or additional observations during the process.