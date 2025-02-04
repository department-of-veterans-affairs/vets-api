# RFC: Data Purge Plan for `FormSubmission` Records

## 1. Title

Data Purge Plan for `FormSubmission` Records

## 2. Summary

This document outlines a data purge plan for `FormSubmission` records stored in the VA.gov PostgreSQL database. The goal is to ensure compliance with best practices for handling Personally Identifiable Information (PII) and Protected Health Information (PHI) by removing sensitive data after a specified retention period while maintaining essential metadata for operational use. The purge process includes deleting associated PDF backups stored in an AWS S3 bucket.

## 3. Background

The `FormSubmission` table contains user-submitted data, including PII and PHI. Associated PDF backups are stored in an S3 bucket. Current retention policies suggest removing user and form data after 60 days post-submission. While the form data is no longer required for operations, minimal metadata (`submission_date` and `benefits_intake_uuid`) will be retained for reporting and referencing. This purge process mitigates risks associated with prolonged retention of sensitive data while maintaining essential operational functionality.

### 3.1 FormSubmission Status

The status of a `FormSubmission` record is determined by a combination of attributes and updates from the Lighthouse Benefits Intake API. The classifications are:

1. **Expired**:

   - Status is explicitly `'expired'`, or no successful processing attempt is recorded within 10 days (`STALE_SLA`) of the latest `FormSubmissionAttempt` creation.
   - Indicates unsuccessful upload within the expected window.

2. **Errored**:

   - Status is `'error'`, signaling a failure during processing.
   - Includes error codes and descriptions logged from the API response.

3. **Successful**:

   - Status is `'vbms'`, indicating successful processing and upload to the Veteran's eFolder in VBMS.

4. **Pending**:
   - Submissions not falling into the above categories remain `'pending'`, awaiting completion or further action.

### 3.2 Error Handling and Retry Mechanisms

To address potential errors or delays in processing:

- **Error Detection**:

  - The `BenefitsIntakeStatusJob` identifies errors during batch processing of pending submissions.
  - Errors are logged with details such as error codes and descriptions.

- **Retries**:

  - Automatic retries are disabled (`Sidekiq.retry = false`). Manual remediation involves:
    - Notifying claimants using email mechanisms tied to the form type.
    - Monitoring unresolved issues via dashboards to enable targeted reprocessing.

- **Monitoring and Alerts**:

  - Metrics on success, failure, and staleness are captured and monitored through a Datadog dashboard.
  - Alerts and notifications ensure timely resolution of silent failures or recurring errors.

- **Fallback and Recovery**:
  - Persistent errors trigger notifications to claimants for corrective action.
  - Records exceeding the SLA are flagged as `'stale'` for further investigation.

## 4. Proposal

### 4.1. Data Retention and Purge Process

- **Retention Policy**:

  - Purge sensitive data from `FormSubmission` records 60 days after `updated_at` when the status is `"vbms"`.
  - Retain:
    - `submission_date` for operational use.
    - `benefits_intake_uuid` for linking PDFs and historical lookups.
  - Keep the `FormSubmission` record intact for metadata and reference.

- **PDF Purge**:

  - Use `benefits_intake_uuid` to identify and delete associated PDFs from S3.

- **Trigger for Purge**:

  - Trigger for records with status `"vbms"`. For unresolved statuses, manual remediation or user notification will apply.

- **Definition of "Purge"**:
  - Replace sensitive fields (e.g., `form_data`) with `nil` or empty values while retaining metadata for structure and reporting.

### 4.2. Job Implementation

- **Scheduled Purge Job**:

  - Run a Sidekiq job daily during off-peak hours.
  - Job steps:
    1. Query `FormSubmission` records with an `updated_at` older than 60 days and a status of `"vbms"`.
    2. Emit a `pii.deleting` event for pre-deletion notifications.
    3. Purge sensitive data from identified records.
    4. Delete associated PDFs from S3.
    5. Emit a `pii.deleted` event to track the purge completion.

- **ActiveSupport Notifications**:

  - **Pre-Deletion**:
    Emit `pii.deleting` to allow subscribers to process or archive data before deletion:

    ```ruby
    ActiveSupport::Notifications.instrument(
      "pii.deleting",
      {
        record_type: "FormSubmission",
        benefits_intake_uuid: form_submission.benefits_intake_uuid,
        current_data: form_submission.attributes,
        scheduled_for_deletion_at: Time.current
      }
    )
    ```

  - **Post-Deletion**:
    Emit `pii.deleted` to log the final deletion:

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

### 4.3. Testing Strategy

- Create dummy records in staging with varying submission dates and statuses.
- Validate:
  - Records with `updated_at` older than 60 days and `"vbms"` status are purged.
  - PDFs are correctly deleted from S3.
  - Records not reaching `"vbms"` are skipped.
- Ensure retention of `submission_date` and `benefits_intake_uuid` for purged records.

### 4.4. Considerations for Delay Between Marking and Deleting

- A brief delay for deletion (via marking) allows for recovery or downstream processing by other systems.
- Explicit notifications or real-time metrics can replace marking if preferred.

### 4.5. Logging and Metrics

- **Logs**:

  - Record purged counts:

    ```plaintext
    INFO: Purge job completed. Records purged: 123, PDFs deleted: 123.
    ```

  - Log errors and retries for failures.

- **Metrics**:

  - Monitor:
    - Job success rates.
    - Time taken per job run.
    - `FormSubmission` table and S3 bucket size over time.

- **Alerts**:
  - Notify failures or anomalies (e.g., low purge counts).

### 4.6. Communication and Documentation

- **Stakeholders**:

  - Review:
    - VFS Platform team (AWS S3 Bucket)
    - Architecture Intent team (vets-api DB)
  - Inform:
    - Veteran Facing Forms team
    - Auth Experience team

- **Documentation**:
  - Maintain detailed purge process and configurations in the project wiki.

### 4.7. Time to Transition to Success (VBMS)

Based on current monitoring data, the time for `FormSubmission` records to transition to the `"vbms"` status varies across form types. The analysis below highlights both the average and maximum durations observed:

#### **Average Time to Success**

The average time for a form to reach the `"vbms"` status is as follows:

- Most forms transition within **1 to 10 days**.
- Certain forms experience longer average processing times. For example:
  - **21P-0847**: **33 days**
  - **21-0966**: **20 days**
  - **21-0972**: **17 days**

These longer averages are outliers compared to the typical processing duration for the majority of form submissions.

#### **Maximum Time to Success**

The maximum time observed for a form to transition to the `"vbms"` status can be significantly longer:

- **40-10007**: **81.4 days** (Longest observed duration).
- Several other forms exhibit maximum times between **40–46 days**:
  - **21-0966**: **46.4 days**
  - **21-4142**: **46.3 days**
  - **686C-674**: **46.3 days**
  - **21P-530V2**: **46.1 days**

While such delays represent edge cases, they indicate the need for continued monitoring and remediation to address prolonged processing times.

#### **Key Takeaway**

- **Typical Transition Time**: Under **10 days** for most forms.
- **Maximum Transition Time**: Up to **81.4 days** for outliers.

These insights provide context for identifying patterns in form processing delays and inform future optimizations to ensure timely submissions.

## 5. Impact

- **Data Security**: Reduces risks by purging sensitive PII/PHI from storage.
- **Operational Continuity**: Retains essential metadata for ongoing use.
- **Resource Optimization**: Frees up storage, improving system performance.

## 6. Open Questions

1. Should a delay for deletion be implemented for recovery purposes?
2. Are additional operational metrics or monitoring requirements necessary?
3. Could the purge impact user-facing features or the Auth Experience team's operations?

## 7. Feedback Request

- Input on the retention and purge plan.
- Suggestions for improving metrics, monitoring, and alerting.
- Feedback on the job implementation strategy.

## 8. Appendices/References

- [Platform PII Coding Best Practices](https://depo-platform-documentation.scrollhelp.site/developer-docs/coding-best-practices-for-pii)
- [Sidekiq Job Scheduling Documentation](https://sidekiq.org/)
- [AWS S3 SDK for Ruby](https://docs.aws.amazon.com/sdk-for-ruby/)
