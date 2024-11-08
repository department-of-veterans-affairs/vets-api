# RFC: Monitoring Strategy for S3 PDF Management

## 1. Title

Monitoring Strategy for S3 PDF Management

## 2. Summary

This document proposes a comprehensive monitoring strategy for the S3 PDF management solution on VA.gov. The goal is to ensure robust performance, reliability, and error tracking while safeguarding sensitive data. The plan will include metrics, logging standards, alert configurations, and escalation protocols to address potential issues promptly.

## 3. Background

The S3 PDF upload service handles benefits-related submissions that include PII and PHI. Monitoring is essential to track the service's performance, detect errors, and ensure compliance with data privacy requirements. Currently, there is no existing monitoring setup for this service. With this new functionality, proactive monitoring will help maintain reliability, minimize costs, and protect sensitive information.

## 4. Proposal

### 4.1. Performance Metrics

Definition of key metrics to be monitored:

- **Upload/Download Success Rate**: Percentage of successful upload and download operations over a defined time window.
  - **Threshold**: Alert if the success rate drops below 98% over a rolling **15-minute window**.
- **Average Upload/Download Time**: Time taken for uploads and downloads to complete.
  - **Threshold**: Alert if the average time exceeds 5 seconds (adjustable based on real-world data once recorded) over a **10-minute window**.
- **Error Rate**: Number of failed uploads/downloads over a defined time period.
  - **Threshold**: Alert if the error rate exceeds 1% of total requests over a **10-minute window**.
- **Service Availability**: Monitor the availability and responsiveness of the S3 service and `vets-api` endpoints.
  - **Threshold**: Alert if services are down for more than **2 minutes**.
  - **Implementation**: This will be managed by a job that checks for service availability. The job is triggered only when the service responds with errors consistent with being unreachable (e.g., network timeouts or 5xx errors). This approach reduces unnecessary checks and focuses on addressing sustained outages.

### 4.2. Logging Standards

- **Sensitive Data Handling**: Ensure that PII and PHI are not included in any logs or alerts. Logs must be scrubbed of sensitive information before being recorded.
- **Upload/Download Events**: Log the following details:
  - **Successful Upload/Download**: Timestamp, operation type, and `benefits_intake_uuid`.
  - **Failed Upload/Download**: Timestamp, operation type, error code, and `benefits_intake_uuid`.
  - **Service Downtime**: Detect and log when services are unreachable or experience outages.
- **Log Integration**: Utilize `Rails.logger` to log events, which will be captured by DataDog.

### 4.3. Alert Configuration

- **Slack Notifications**: Alerts should be routed to the `veteran-facing-forms-notifications` channel within the OCTO DSVA Slack workspace.
- **Alert Types**:
  - **Performance Alerts**: Triggered if performance metrics exceed defined thresholds (e.g., high error rate or slow download speeds).
  - **Error Alerts**: Triggered on failed uploads/downloads with error details (scrubbed for PII/PHI).
  - **Service Downtime Alerts**: Triggered when services are unavailable for more than the defined threshold, based on availability checks managed by the job described above.
- **Escalation Protocol**:
  - **Tier 1**: Initial alert, handled by the person on-call.
  - **Tier 2**: If unresolved for 30 minutes, escalate to the engineering team lead.
  - **Tier 3**: If unresolved for 1 hour, escalate to the DevOps team via the `vfs-platform-support` channel (or by tagging VFS Platform DevOps in the alert).

### 4.4. DataDog Dashboard

- **Dashboard Setup**: Create a DataDog dashboard to visualize key metrics and provide an at-a-glance view of the service's health.
- **Metrics to Display**:
  - Upload/Download success and error rates.
  - Average upload/download times.
  - Alerts summary and service availability status.
- **Historical Analysis**: Enable trend analysis to identify performance improvements or issues over time.

### 4.5. Integration with Existing Tools

- **Jenkins Integration**: Ensure that deployments include automated tests to validate the monitoring setup.
- **ArgoCD**: Include monitoring configurations as part of the CI/CD pipeline to automatically deploy updates.
- **Flipper**: Consider future scenarios where feature flags may alter the monitoring logic. Implement checks to confirm whether feature flags are active and adapt the monitoring plan accordingly.

## 5. Impact

- **Performance Monitoring**: Improved detection of issues, reducing downtime and costs associated with S3 usage.
- **Proactive Response**: Real-time alerts to minimize the impact of failures.
- **Data Privacy Compliance**: Ensures PII and PHI are never exposed in logs or alerts, maintaining compliance with data privacy requirements.
- **Scalable Framework**: A foundation that can be extended as the service evolves or as new features are introduced.

## 6. Open Questions

- **What adjustments should be made to the default thresholds?**
- **Are there additional tools or integrations to consider (e.g., more robust alerting mechanisms)?**
- **How should incidents be reported to external teams if necessary (e.g., upstream data issues)?**

## 7. Feedback Request

- Feedback on the proposed metrics and thresholds.
- Input on the escalation protocol and notification channels.
- Suggestions on additional monitoring tools or best practices.

## 8. Appendices/References

- [Error Remediation Architecture](../../../../modules/simple_forms_api/app/services/simple_forms_api/form_remediation/docs/error_remediation_architecture.png)
- [Service Architecture Documentation](../../../../modules/simple_forms_api/app/services/simple_forms_api/form_remediation/docs/README.md)
- [Platform PII Coding Best Practices](https://depo-platform-documentation.scrollhelp.site/developer-docs/coding-best-practices-for-pii)
- [Service Architecture Diagram](../../../../modules/simple_forms_api/app/services/simple_forms_api/form_remediation/docs/error_remediation_architecture.png)
- [Platform DataDog Documentation](https://depo-platform-documentation.scrollhelp.site/developer-docs/get-acquainted-with-datadog)
- [Platform Performance Monitoring Documentation](https://depo-platform-documentation.scrollhelp.site/developer-docs/monitoring-performance)
