# RFC: Transitioning PDF Uploads to Asynchronous Sidekiq Jobs

## 1. Title

Transitioning PDF Uploads to Asynchronous Sidekiq Jobs

## 2. Summary

This document proposes transitioning the PDF upload process from a synchronous workflow to an asynchronous Sidekiq job within the VA.gov platform. By moving to asynchronous processing, we aim to improve user experience on the form submission Confirmation page by reducing wait times, while also enhancing error handling and resilience during S3 outages. The RFC outlines the technical requirements, necessary frontend changes, error-handling strategies, and other considerations for implementing this change.

## 3. Background

Currently, PDFs are generated and uploaded synchronously to the `vff-simple-forms` S3 bucket when users submit forms. This process can cause delays on the Confirmation page, as users must wait for the upload to complete before accessing their submission PDF. Additionally, any failures during the upload result in immediate user-facing errors, with limited retry or resilience mechanisms in place. This RFC proposes handling the upload asynchronously with Sidekiq, which would enable faster form submissions, provide more robust error handling, and improve the user experience.

## 4. Proposal

### 4.1 Asynchronous Upload with Sidekiq

#### Backend Modifications

1. **UploadsController Modification**:
   1. Upon form submission, the controller will return a 200 response immediately and trigger a Sidekiq job for PDF uploads. This approach allows form submissions to complete without waiting for the PDF upload to finish.
   1. The response will include the `benefits_intake_uuid` to help track the submission state. The frontend will use this identifier to poll for upload status.
1. **New Endpoint for Fetching PDF Status**:
   1. A new endpoint will allow the frontend to check the status of the PDF upload. This endpoint will handle states such as "pending," "completed," or "failed," and will return a URL for download once the upload completes.
   1. Alternatively, the frontend could initiate the entire upload and retrieval process, creating a more straightforward lifecycle with one request starting the workflow and another checking for completion.
1. **Sidekiq Job Specifications**:
   1. **Retry Limit**: Set to 3 retries in case of transient errors.
   1. **Error Handling**: Log failures and notify users if upload fails, without displaying technical error details.
   1. **Pollable State Information**: Sidekiq jobs will need to update a status in the database so the frontend can query the current upload state.

#### Frontend Modifications

1. **Status Messaging**:
   1. A loading component on the Confirmation page will display an "Uploading PDF..." message while the upload is in progress.
   1. Once the upload is complete, the message updates to a download link for the user's PDF.
1. **User-Friendly Error Messaging**:
   1. If the upload fails after all retries, the frontend will display a user-friendly error message, such as "We couldn't save your form submission. Please try again later."
1. **Polling Workflow**:
   1. The frontend will initiate polling to check for the PDF status using the `benefits_intake_uuid`, ensuring user visibility into the status at each stage (e.g., "submitted," "processing," "complete").

### 4.2 Technical Specifications

#### Backend (vets-api)

1. **Components**:
   1. `SimpleFormsApi::FormRemediation::S3Client`: Update to support Sidekiq's asynchronous operations.
   1. **Retries and Error Logging**: Configure Sidekiq job retries (3) and log detailed error context for troubleshooting.
1. **New Endpoint**:
   1. An endpoint will be added to provide the upload status and URL for the PDF download upon completion.

#### Frontend (vets-website)

1. **Status Messaging**:
   1. Display a spinner and "Uploading PDF..." message during the upload.
   1. Once upload completes, replace the message with a download link, allowing users to download their submission PDF.
1. **Polling Logic**:
   1. Implement a polling mechanism to check PDF upload status, ensuring multiple frontend states (e.g., "success", "error", "in-progress") are accurately reflected to the user.

### 4.3 Error Handling

1. **S3 Outages**:
   1. In case of an S3 outage, trigger a monitoring job to periodically reattempt uploads once the service is restored.
   1. Error handling within the Sidekiq job should include contextual error logging for easier debugging and analysis.

2. **User Notifications**:
   1. User-friendly messages on the frontend, avoiding technical jargon.
   1. A retry link may be presented for the user to attempt the upload again in case of prolonged failure.

### 4.4 Security and Compliance

1. **PII and PHI Protection**:
   1. The same PII and PHI handling standards will apply, with no additional persistence beyond necessary retention.
   1. Sensitive data will be scrubbed from logs to prevent exposure.

1. **Performance and Resilience**:
   1. Async processing is expected to improve frontend wait times by up to 50%, with Sidekiq managing heavy load in the background.
   1. Track Sidekiq performance metrics (job success/failure rates, processing times) to evaluate improvements.

### 4.5 Monitoring and Alerting

1. **Metrics and Alerts**:
   1. Track key metrics like upload success/error rates, average processing times, and threshold-based alerts.
   1. Configure alerts for error rates exceeding thresholds (e.g., >1% error rate in 10 minutes).
   1. Alerts should route to `veteran-facing-forms-notifications` on OCTO DSVA Slack.
1. **Escalation Protocol**:
   1. **Tier 1**: Initial alert handled by on-call engineer.
   1. **Tier 2**: Escalate to team lead if unresolved within 30 minutes.
   1. **Tier 3**: Escalate to VFS Platform DevOps if unresolved within 1 hour.

### 4.6 DataDog Dashboard

1. **Dashboard Setup**:
   1. Display upload success/error rates, average processing times, and alerts summary.
   1. Track metrics historically to identify performance trends and improvement opportunities.

### 4.7 Integration with Existing Tools

1. **Jenkins Integration**:
   1. Ensure automated tests validate the asynchronous upload workflow as part of deployments.
1. **ArgoCD**:
   1. Deploy monitoring configurations via CI/CD pipeline to ensure consistency.
1. **Flipper**:
   1. Enable feature-flagging to allow controlled rollout of the asynchronous upload process.

## 5. Impact and Tradeoffs

1. **Increased Complexity**:
   1. Asynchronous processing with Sidekiq introduces additional complexity for both the frontend and backend. Tracking job states, handling polling, and managing error notifications create new technical challenges and maintenance overhead.
1. **User Experience Gains**:
   1. Although async processing can reduce wait times on the Confirmation page by up to 50%, the current synchronous wait times may already be tolerable. Without concrete metrics showing significant user impact, the added complexity may not justify the gain.
1. **Resilience vs. Simplicity**:
   1. While an async solution provides greater resilience to S3 outages, these outages are rare. The current synchronous approach keeps the user experience simpler and more predictable.
1. **Scalability Benefits**:
   1. Offloading uploads to Sidekiq reduces backend load during peak times, which could improve scalability. However, scalability concerns may be premature given the current traffic levels.
1. **Error Handling Limitations**:
   1. Async workflows can obscure error handling from users, requiring robust retry and monitoring to ensure no failed uploads are missed. A synchronous approach offers more immediate and transparent error feedback.

## 6. Open Questions

1. **Lifecycle Management with Single API Calls**:
   1. Would handling both upload initiation and status polling with one API call improve simplicity without reducing functionality? This would prevent frontend polling and maintain a more synchronous user experience.
1. **S3 Monitoring Interval**:
   1. What interval should the monitoring job use to check for S3 service restoration?
1. **User Retry Option**:
   1. Should users be able to retry failed uploads manually, or should it be fully automated?
1. **Persistent Caching**:
   1. Should downloaded PDFs be cached locally on the user's device, or should caching be disabled to avoid repeated requests?
1. **Job Failure Notification**:
   1. Are additional notifications required in parts of the application beyond the Confirmation page?

## 7. Feedback Request

1. **Feedback on Complexity vs. Benefits**:
   1. Is the async approach justified given the low frequency of S3 outages and relatively low traffic volume?
1. **Error Handling Preferences**:
   1. Should retry options be handled solely on the backend, or should there be a retry link for users?
1. **Polling Interval for Status Updates**:
   1. What is an optimal interval for frontend polling without impacting performance?

## 8. Appendices/References

1. [Architectural Intent Meeting Notes](https://github.com/department-of-veterans-affairs/va.gov-team/issues/91829)
1. [Platform PII Handling Best Practices](https://depo-platform-documentation.scrollhelp.site/developer-docs/coding-best-practices-for-pii)
1. [DataDog Monitoring Guide](https://depo-platform-documentation.scrollhelp.site/developer-docs/get-acquainted-with-datadog)
1. [Platform Performance Monitoring](https://depo-platform-documentation.scrollhelp.site/developer-docs/monitoring-performance)
