# RFC: Data Purge Plan for `FormSubmission` Records

## 1. Title

Data Purge Plan for `FormSubmission` Records

## 2. Summary

This document outlines a data purge plan for `FormSubmission` records stored in the VA.gov PostgreSQL database. The goal is to ensure compliance with best practices for handling Personally Identifiable Information (PII) and Protected Health Information (PHI) by removing sensitive data after a specified retention period while maintaining essential metadata for operational use. The purge process will also include deleting associated PDF backups stored in an AWS S3 bucket.

## 3. Background

The `FormSubmission` table contains user-submitted data, including PII and PHI. Associated PDF backups are also stored in a team's S3 bucket. Current retention policies suggest removing user and form data after 60 days post-submission. While the form data is no longer required for operations, minimal metadata (`submission_date` and `benefits_intake_uuid`) will be retained for reporting and referencing. This purge process will help mitigate risks related to prolonged retention of sensitive data while maintaining functionality for users to download their PDF backups during the retention period.

### 3.1 FormSubmission Status

The status of a `FormSubmission` record is determined through a combination of attributes and a background job that queries the Lighthouse Benefits Intake API. This ensures the status is accurately updated, and appropriate actions are taken in response to errors or delays. The classification is as follows:

1. **Expired**:

   - Status is explicitly set to `'expired'`.
   - OR, if no successful processing attempt is recorded within 10 days (`STALE_SLA`) of the latest `FormSubmissionAttempt` creation.
   - Indicates that documents were not successfully uploaded within the expected window.

2. **Errored**:

   - Status is set to `'error'`, signaling a failure during processing.
   - Includes additional error details logged from the API response, such as error codes and descriptions.

3. **Successful**:

   - Status is set to `'vbms'`, indicating the form submission has been successfully processed and uploaded into the Veteran's eFolder within the VBMS system.

4. **Pending**:
   - Any status that does not fall into the above categories is considered `'pending'`, representing submissions awaiting completion or further processing.

### 3.2 Error Handling and Retry Mechanisms

To address potential errors or delays in processing:

- **Error Detection**:

  - The `BenefitsIntakeStatusJob` identifies errors during the batch processing of pending submissions by querying the API.
  - If a submission's status is `'error'` or `'expired'`, detailed error messages are logged, including the error code and description.

- **Retries**:

  - Submissions that encounter errors are not retried automatically (`Sidekiq.retry = false` for the job). However, a manual remediation process is in place:
    - Notifications are sent to stakeholders, such as claimants, using email mechanisms tied to the form type.
    - Failure logs and monitoring dashboards provide visibility into unresolved issues, enabling targeted reprocessing as necessary.

- **Monitoring and Alerts**:

  - Metrics are captured for each submission's status update, including success, failure, and staleness. These metrics are monitored through a Datadog dashboard, allowing for proactive identification of systemic issues.
  - Notifications are sent via associated monitoring services (e.g., Burials, Pensions, Dependents), ensuring team members are aware of silent failures or recurring errors.

- **Fallback and Recovery**:
  - If errors persist, claimants associated with failed submissions receive notifications, enabling them to take corrective action or contact support for resolution.
  - Records exceeding the SLA are flagged as `'stale'` for further investigation.

## 4. Proposal

### 4.1. Data Retention and Purge Process

- **Retention Policy**:

  - Purge sensitive data from `FormSubmission` records 60 days after the `updated_at` once `FormSubmission.submission_status` has been set to `vbms`.
  - Retain:
    - `submission_date` for operational timelines.
    - `benefits_intake_uuid` for linking associated PDFs as well as historical lookups via the Benefits Intake API.
  - Leave the `FormSubmission` record intact for future reference.

- **PDF Purge**:

  - Use `benefits_intake_uuid` to identify and delete PDFs from each team's AWS S3 bucket.

- **Trigger for Purge**:

  - Purge records where the status is `"vbms"`, marking the final stage of submission processing.
  - For records not reaching `"vbms"`, resolve via manual remediation or notify users.

- **Definition of "Purge"**:
  - Replace the `form_data` field with `nil` or empty values to remove sensitive data while retaining the structure of the record for metadata purposes.

### 4.2. Job Implementation

- **Scheduled Purge Job**:

  - Utilize Sidekiq to run a background job daily during off-peak hours.
  - Job steps:
    1. Query `FormSubmission` records with an `updated_at` older than 60 days and a status of `"vbms"`.
    2. Purge sensitive data from identified records.
    3. Delete associated PDFs from S3.

- **ActiveSupport Notification for Deletion**:
  - Emit an `ActiveSupport::Notification` event when deleting PII:
    ```ruby
    ActiveSupport::Notifications.instrument(
      "pii.deleted",
      {
        record_type: "FormSubmission",
        benefits_intake_uuid: form_submission.benefits_intake_uuid,
        deleted_at: Time.current
      }
    )
    ```
  - This enables tracking, metrics, and integration with other systems for audit trails or further cleanup.

### 4.3. Testing Strategy

- Create dummy records in the staging environment with varying submission dates and statuses for testing.
- Validate that:
  - Records with an `updated_at` older than 60 days and a `"vbms"` status are purged.
  - PDFs are correctly identified and deleted from S3.
  - Records not reaching `"vbms"` are skipped.
- Write assertions to ensure `submission_date` and `benefits_intake_uuid` retention for purged records.

### 4.4. Considerations for Delay Between Marking and Deleting

- While the default approach is to delete records and PDFs immediately after they meet the criteria, consider the option to delay deletion by marking records for a brief period. This provides a buffer for potential recovery or downstream processing by other systems.
- Explicit notifications or metrics can replace the need for marking if real-time tracking is implemented.

### 4.5. Logging and Metrics

- **Logs**:

  - Record the number of records and PDFs purged in each job run:

    ```plaintext
      INFO: Purge job completed. Records purged: 123, PDFs deleted: 123.
    ```

  - Log errors and retries for failed operations.

- **Metrics**:

  - Monitor:
    - Job success rates.
    - Time taken for each purge job.
    - Size of the `FormSubmission` table and S3 bucket over time.

- **Alerts**:
  - Set up alerts for job failures or anomalies (e.g., low purge counts).

### 4.6. Communication and Documentation

- **Stakeholders**:

  - Review by:
    - VFS Platform team (AWS S3 Bucket)
    - Architecture Intent team (vets-api DB)
  - Inform:
    - Veteran Facing Forms team
    - Auth Experience team

- **Documentation**:
  - Document the purge process, triggers, and configurations in the project wiki.

## 5. Impact

- **Data Security**: Reduces risks by removing sensitive PII/PHI from the database and S3.
- **Operational Continuity**: Retains essential metadata for continued operational use.
- **Resource Optimization**: Frees up database and S3 storage, improving system performance.

## 6. Open Questions

1. Should a delay between marking records for deletion and purging them be implemented to allow for recovery?
2. Are there additional operational metrics or monitoring requirements we should consider?
3. Are there concerns from the Auth Experience team regarding purge impacts on user-facing features?

## 7. Feedback Request

- Input on the proposed retention and purge plan.
- Suggestions for metrics, monitoring, and alerting best practices.
- Feedback on the job implementation strategy and delay mechanism.

## 8. Appendices/References

- [Platform PII Coding Best Practices](https://depo-platform-documentation.scrollhelp.site/developer-docs/coding-best-practices-for-pii)
- [Sidekiq Job Scheduling Documentation](https://sidekiq.org/)
- [AWS S3 SDK for Ruby](https://docs.aws.amazon.com/sdk-for-ruby/)
