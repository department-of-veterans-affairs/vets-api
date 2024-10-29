# RFC: Transitioning PDF Uploads to Asynchronous Sidekiq Jobs

## 1. Title

Transitioning PDF Uploads to Asynchronous Sidekiq Jobs

## 2. Summary

This document proposes transitioning the PDF upload process from a synchronous workflow to an asynchronous Sidekiq job within the VA.gov platform. By moving to asynchronous processing, we aim to improve user experience on the form submission Confirmation page by reducing wait times, while also enhancing error handling and resilience during S3 outages. The RFC outlines the technical requirements, necessary frontend changes, error-handling strategies, security, and performance considerations for implementing this change.

## 3. Background

Currently, PDFs are generated and uploaded synchronously to the `vff-simple-forms` S3 bucket when users submit forms. This process causes delays on the Confirmation page, as users must wait for the upload to complete before accessing their submission PDF. Additionally, any failures during the upload result in immediate user-facing errors, with limited retry or resilience mechanisms in place. This RFC proposes handling the upload asynchronously with Sidekiq, which would enable faster form submissions, provide more robust error handling, and improve the user experience.

## 4. Proposal

### 4.1 Asynchronous Upload with Sidekiq

- **Backend Modifications**:
  - Modify the `UploadsController#submit` action to trigger a Sidekiq job for PDF uploads, allowing form submissions to complete without waiting for the PDF upload.
  - The Sidekiq job will handle the PDF upload to S3 and return a presigned URL to the backend, where it will be made available for the frontend to display.
  - Retry Limit: Set to 3 retries in case of transient errors.
  - Failure Handling: Log errors and notify users if upload fails, without displaying technical error details.

- **Frontend Modifications**:
  - Display a spinner and "Uploading PDF..." message on the Confirmation page during upload.
  - Once the upload is complete, replace the message with a download link.
  - In case of a failure, display a user-friendly error message, such as "We couldn't save your form submission. Please try again later."

- **Error Handling and Monitoring**:
  - A dedicated monitoring job will periodically check S3 status during outages, reattempting uploads as S3 becomes available.
  - Log and alert for both temporary and long-term S3 outages, ensuring users receive timely information.
  - In the event of temporary files being deleted due to pod lifecycle issues, a call to the SimpleFormsApi::FormRemediation::SubmissionArchive service could hydrate the form submission via the `benefits_intake_uuid` confirmation code. Which could in turn upload the PDF to the S3 Client.

### 4.2 Technical Specifications

#### Backend (vets-api)

- **Components**:
  - `SimpleFormsApi::FormRemediation::S3Client`: Modify to support Sidekiq's asynchronous operations.
  - **Retries and Error Logging**: Configure Sidekiq job retries (3) and log detailed error context for troubleshooting.

#### Frontend (vets-website)

- **Status Messaging**:
  - A loading component on the Confirmation page will display an "Uploading PDF..." message while the upload is in progress.
  - On completion, the message updates to a download link, allowing users to download their submission PDF.

- **User-Friendly Error Messaging**:
  - If upload fails after all retries, show an error message on the Confirmation page, offering a retry link if needed.

### 4.3 Error Handling

- **S3 Outages**:
  - In the event of an S3 outage, trigger a monitoring job to periodically reattempt uploads once service is restored.
  - Error handling within the Sidekiq job should include contextual error logging for easier debugging and analysis.

- **User Notifications**:
  - User-friendly messages on the frontend, avoiding technical jargon.
  - Consider offering a retry button on persistent failures.

### 4.4 Security and Compliance

- **PII and PHI Protection**:
  - PDFs will continue to be handled in accordance with current PII and PHI standards, with pre-signed URLs provided for secure access.
  - Scrubbing sensitive data from logs and alerts to ensure compliance.

- **Performance and Resilience**:
  - Async processing will reduce frontend wait times by up to 50%, with Sidekiq providing a buffer for heavy loads.
  - Track Sidekiq performance metrics (job success/failure rates, processing times) to evaluate improvements.

### 4.5 Monitoring and Alerting

- **Metrics and Alerts**:
  - Track key metrics: upload success rates, average processing times, and error rates.
  - Configure alerts for error rates exceeding thresholds (e.g., >1% error rate in 10 minutes).
  - Alerts should route to `veteran-facing-forms-notifications` on OCTO DSVA Slack.

- **Escalation Protocol**:
  - **Tier 1**: Initial alert handled by on-call engineer.
  - **Tier 2**: Escalate to team lead if unresolved within 30 minutes.
  - **Tier 3**: Escalate to VFS Platform DevOps if unresolved within 1 hour.

### 4.6 DataDog Dashboard

- **Dashboard Setup**:
  - Display upload success/error rates, average processing times, and alerts summary.
  - Track metrics historically to identify performance trends and improvement opportunities.

### 4.7 Integration with Existing Tools

- **Jenkins Integration**: Ensure automated tests validate the asynchronous upload workflow as part of deployments.
- **ArgoCD**: Deploy monitoring configurations via CI/CD pipeline to ensure consistency.
- **Flipper**: Enable feature-flagging to allow controlled rollout of the asynchronous upload process.

## 5. Impact

- **Enhanced User Experience**: Reduced wait times on the Confirmation page, allowing users quicker access to submission confirmations.
- **Improved Reliability**: Resilience against S3 outages, with better error-handling and retry mechanisms.
- **Compliance**: Consistent handling of sensitive data in logs, with pre-signed URLs for secure PDF downloads.
- **Scalability**: Offloading PDF uploads to Sidekiq will reduce synchronous load on the backend, allowing for better scalability during high-traffic periods.

## 6. Open Questions

- **S3 Monitoring Interval**: How frequently should the monitoring job check for S3 service restoration?
- **User Retry Option**: Should users be able to retry failed uploads manually, or should it be fully automated?
- **Job Failure Notification**: Are additional notifications required in parts of the application beyond the Confirmation page?

## 7. Feedback Request

- Feedback on the proposed async workflow and error-handling strategies.
- Input on retry and escalation protocols.
- Suggestions for additional metrics or monitoring improvements.

## 8. Appendices/References

- [Architectural Intent Meeting Notes](https://github.com/department-of-veterans-affairs/va.gov-team/issues/91829)
- [Platform PII Handling Best Practices](https://depo-platform-documentation.scrollhelp.site/developer-docs/coding-best-practices-for-pii)
- [DataDog Monitoring Guide](https://depo-platform-documentation.scrollhelp.site/developer-docs/get-acquainted-with-datadog)
- [Platform Performance Monitoring](https://depo-platform-documentation.scrollhelp.site/developer-docs/monitoring-performance)
