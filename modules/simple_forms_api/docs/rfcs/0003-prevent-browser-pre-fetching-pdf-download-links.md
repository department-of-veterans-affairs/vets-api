# RFC: Preventing Browser Pre-fetching for PDF Download Links

## 1. Title

Preventing Browser Pre-fetching for PDF Download Links

## 2. Summary

This document proposes measures to prevent browsers from automatically pre-fetching PDF files when links to these files appear on a page within `vets-website`. Automatic pre-fetching can incur unnecessary costs, impact site performance, and skew metrics by logging accesses that were not user-initiated. We recommend leveraging JavaScript to control download initiation, thereby avoiding the default browser behavior of automatically fetching linked resources. This RFC outlines the proposed methods, technical requirements, best practices, and considerations for managing PDF download links more efficiently.

## 3. Background

Currently, there is a concern that PDF download links may be unintentionally pre-fetched by browsers, especially if users' browser settings or site configurations enable aggressive caching or pre-fetching. While we haven't observed pre-fetching behavior directly within the application, there is a risk of it being triggered if prefetch attributes are added or if the link attributes change in the future. This RFC explores best practices and methods to prevent pre-fetching, including implementing controlled download mechanisms via JavaScript. Such precautions aim to protect against potential cost, performance, and metric-tracking issues.

## 4. Proposal

### 4.1 Controlled Download Trigger with JavaScript

#### Backend Modifications

No modifications are required on the backend for this proposal since pre-fetching prevention is managed on the frontend. However, server logs should include tracking adjustments if we begin using JavaScript-triggered downloads to ensure these events are captured consistently.

#### Frontend Modifications

1. **JavaScript-based Download Trigger**:
    1. Replace direct anchor (`<a>`) tags for downloading PDFs with a JavaScript function that triggers the download only when a user clicks the link.
    1. The download link will call a JavaScript function, such as `downloadPDF()`, which initiates the fetch only when activated. This prevents browsers from pre-fetching based on link visibility.

1. **Caching Control**:
    1. Use headers to specify caching rules, ensuring PDFs are cached locally for a set duration to reduce repeated downloads. A balance between performance and fresh data will need to be maintained based on industry standards.

1. **Frontend Standards**:
    1. Since `vets-website` is a React-based application, the standard for controlled downloads should use plain TypeScript within the React framework. The approach will also ensure accessibility standards are met.

1. **Accessibility Considerations**:
    1. Use ARIA labels and appropriate focus management to ensure the JavaScript-triggered download is accessible to screen readers and assistive technologies, aligning with VA.gov’s accessibility standards.

### 4.2 Technical Specifications

#### Download Event Tracking

1. **Tracking Download Events**:
    1. Implement event tracking to log each user-initiated download. This will provide more accurate metrics by excluding any automated or pre-fetching behavior.
    1. Event tracking can be integrated with Google Analytics or DataDog for monitoring download actions and identifying any trends or anomalies.

1. **Monitoring Pre-fetch Impact**:
    1. Configure monitoring tools (e.g., DataDog or Google Analytics) to observe download patterns. Establish metrics to ensure the controlled download approach effectively reduces unintended fetches and maintains accurate download counts.

#### Cost and Performance Metrics

1. **Performance Metrics**:
    1. Utilize industry standards for performance benchmarks (e.g., no impact on page load time, minimal CPU usage on link display).
    1. Monitor page load times and memory usage associated with PDF links to ensure they remain within acceptable thresholds.

1. **Cost Monitoring**:
    1. Monitor S3 usage and costs. Establish a baseline based on expected usage to gauge any cost fluctuations potentially caused by unintentional downloads.

### 4.3 Error Handling

Since this is a frontend-based solution, error handling will include:

1. **JavaScript Errors**:
    1. Implement basic error handling within the `downloadPDF()` function to notify users if a download fails.
    1. Use `try-catch` blocks to handle errors gracefully, displaying a message like "Download failed, please try again."

1. **Logging Errors for Monitoring**:
    1. Log JavaScript download initiation errors in DataDog, tagging them as client-side events. This tracking will help capture failed download attempts.

### 4.4 Security and Compliance

1. **PII and PHI Protection**:
    1. Ensure any user-related data is anonymized in download tracking events.
    1. The download link and associated tracking must comply with VA.gov’s PII and PHI handling standards to avoid sensitive data exposure.

1. **Compliance with VA.gov Standards**:
    1. Ensure that all modifications, particularly those related to accessibility and JavaScript control, comply with VA.gov’s technical and security standards.

### 4.5 Monitoring and Alerting

1. **Metrics and Alerts**:
    1. Establish tracking for user-initiated downloads versus automated fetches to monitor for compliance with the controlled download setup.
    1. Set alerts if download counts exceed expected thresholds, suggesting possible unintentional behavior.

1. **Dashboard Setup**:
    1. Use a DataDog dashboard to track download counts, error rates, and user engagement metrics related to PDF access.

### 4.6 Integration with Existing Tools

1. **DataDog and Google Analytics**:
    1. Track download actions using these tools to capture user-initiated events and analyze download patterns.

1. **Jenkins and ArgoCD**:
    1. Ensure automated tests validate the JavaScript-triggered download functionality as part of CI/CD deployments.

## 5. Impact and Tradeoffs

1. **Cost Savings and Performance**:
    1. Preventing unintended pre-fetching will reduce S3 costs related to PDF access. However, given current pre-fetch behavior is minimal, the cost savings may be modest. Controlled downloads offer a future-proof solution to scale up without facing hidden costs from automated fetches.

1. **Added Complexity**:
    1. Moving from direct links to JavaScript-controlled downloads increases complexity slightly but remains manageable within `vets-website`. This complexity is offset by improved download accuracy and control over pre-fetching.

1. **User Experience and Accessibility**:
    1. This approach should not introduce any noticeable delay for users. Accessibility practices, if adhered to, will maintain or improve overall usability.

1. **Metric Accuracy**:
    1. Using JavaScript-triggered downloads provides more accurate tracking of actual user interaction, helping separate genuine downloads from potential pre-fetches. This will improve data quality for usage metrics and analysis.

## 6. Open Questions

1. **JavaScript Standards and Libraries**:
    1. Should this approach leverage any specific libraries (e.g., a React hook or a custom component) within `vets-website`?

1. **Event Tracking Integration**:
    1. How should tracking be optimized across DataDog and Google Analytics to ensure consistency?

1. **Caching Tradeoff**:
    1. Should PDFs be cached locally, or should every access trigger a fresh download? This may depend on the frequency of PDF updates and expected user behavior.

1. **Confirmation of Existing JavaScript Usage**:
    1. Confirm if JavaScript-based download controls are currently implemented elsewhere on `vets-website` to ensure consistent standards.

## 7. Feedback Request

1. **Download Control and Complexity**:
    1. Does the JavaScript-triggered download method add too much complexity relative to the expected cost and performance gains?

1. **Metric Tracking Preferences**:
    1. Are there preferences for specific metrics or alerts that should be prioritized for download events?

1. **Caching Approach**:
    1. Should PDFs be cached to reduce repeated download requests? What are the pros and cons in terms of user experience and cost?

## 8. Appendices/References

1. [Architectural Intent Meeting Notes](https://github.com/department-of-veterans-affairs/va.gov-team/issues/91829)
1. [Platform PII Handling Best Practices](https://depo-platform-documentation.scrollhelp.site/developer-docs/coding-best-practices-for-pii)
1. [DataDog Monitoring Guide](https://depo-platform-documentation.scrollhelp.site/developer-docs/get-acquainted-with-datadog)
1. [Platform Performance Monitoring](https://depo-platform-documentation.scrollhelp.site/developer-docs/monitoring-performance)
