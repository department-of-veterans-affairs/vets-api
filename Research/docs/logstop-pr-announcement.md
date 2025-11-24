# Logstop PII Filtering - Meeting Notes & Slack Announcement

## Meeting Talking Points (3-5 minutes)

**What:** Implementing Logstop gem for content-based PII filtering in Rails logs

**Why:** Current `filter_parameters` can't catch PII typed into allowed fields (e.g., user types SSN in a "comments" field). Following up on [PII Prevention Research](https://github.com/department-of-veterans-affairs/va.gov-team/issues/117875) and 3/7/2025 PII leak incident.

**How:** Logstop scans actual log content for PII patterns and replaces them with `[FILTERED]`

**What Gets Filtered:**
- **Logstop built-in:** SSN (XXX-XX-XXXX), emails, phone numbers, credit cards
- **VA custom patterns:**
  - SSN without dashes (9 digits)
  - EDIPI (10 digits)
  - VA file numbers

**Risk Assessment:**
- Low risk - well-tested gem, defense-in-depth approach
- Works alongside existing `filter_parameters` (not replacing it)
- Easy rollback by removing initializer
- Minor false positive risk on 10-digit numbers (order IDs, tracking numbers) - we accept this to avoid PII leaks

**Soliciting Feedback:**
- Are there other VA-specific PII patterns we should add?
- Any concerns about false positives on legitimate IDs?
- Any use cases where we need to see these numbers in logs?

**PR:** https://github.com/department-of-veterans-affairs/vets-api/pull/25272

---

## Slack Announcement

**Channel:** `#vfs-platform-support` or `#backend`

---

### 🔒 New: Logstop PII Filtering in vets-api

Hi team! I've opened a PR to add content-based PII filtering to vets-api logs using the [Logstop gem](https://github.com/ankane/logstop).

**📋 Background**
Our current `filter_parameters` approach filters by parameter name (allowlist), but can't detect PII when users type sensitive data into allowed fields. This adds a second layer of defense by scanning actual log content for PII patterns.

**🛡️ What Gets Filtered**

*Logstop built-in patterns:*
- SSN (XXX-XX-XXXX format)
- Email addresses
- Phone numbers
- Credit card numbers

*VA custom patterns:*
- SSN without dashes (9 digits) → `[SSN_FILTERED]`
- EDIPI (10 digits) → `[EDIPI_FILTERED]`
- VA file numbers → `[VA_FILE_NUMBER_FILTERED]`

**⚠️ Tradeoffs**
- 10-digit pattern may filter order numbers, tracking IDs (we accept this to avoid PII leaks)

**🔍 Requesting Feedback**
1. Are there other VA-specific PII patterns we should add?
2. Any concerns about false positives on legitimate non-PII IDs?
3. Do you have use cases where you need to see these numbers in logs for debugging?

**PR:** https://github.com/department-of-veterans-affairs/vets-api/pull/25272

Please review and comment by **[date]**. Thanks! 🙏

---

cc: @backend-review-group
