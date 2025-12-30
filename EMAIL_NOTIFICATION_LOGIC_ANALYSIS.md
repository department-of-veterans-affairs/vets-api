# Analysis of Email Notification Logic for Contact Info Changes

## Focus Area
**Email sending logic when users update or confirm their email addresses**

Related to: `Settings.vanotify.services.va_gov.template_id.contact_info_change`

---

## Key File Reviewed
**File:** `lib/va_profile/contact_information/v2/service.rb`

This is the main service class that handles contact information updates (email, address, phone) and controls when notification emails are sent to users.

---

## Email Notification Logic Overview

The service file contains **TWO distinct email notification methods**:

### 1. `send_contact_change_notification` (Lines 251-269)
**Purpose:** Sends notification for **address and phone number changes**

**When it triggers:**
- Called from `get_address_transaction_status` (line 123)
- Called from `get_telephone_transaction_status` (line 192)

**Logic flow:**
```ruby
def send_contact_change_notification(transaction_status, personalisation)
  transaction = transaction_status.transaction

  if transaction.completed_success?                           # ← Check #1: Transaction must be successful
    transaction_id = transaction.id
    return if TransactionNotification.find(transaction_id).present?  # ← Check #2: Prevent duplicate notifications

    email = @user.va_profile_email                           # ← Check #3: User must have email
    return if email.blank?

    # Send the notification
    VANotifyEmailJob.perform_async(
      email,
      CONTACT_INFO_CHANGE_TEMPLATE,
      get_email_personalisation(personalisation)
    )

    TransactionNotification.create(transaction_id:)          # ← Record that notification was sent
  end
end
```

**Three conditions must be met:**
1. ✅ Transaction status is `completed_success?`
2. ✅ No existing `TransactionNotification` for this transaction ID (prevents duplicates)
3. ✅ User has a valid `va_profile_email` (not blank)

---

### 2. `send_email_change_notification` (Lines 271-291)
**Purpose:** Sends notifications for **email address changes** (sends to BOTH old and new email)

**When it triggers:**
- Called from `get_email_transaction_status` (line 164)

**Logic flow:**
```ruby
def send_email_change_notification(transaction_status)
  transaction = transaction_status.transaction

  if transaction.completed_success?                           # ← Check #1: Transaction must be successful
    old_email = OldEmail.find(transaction.id)                # ← Check #2: Must have old email stored
    return if old_email.nil?

    personalisation = get_email_personalisation(:email)

    # Send notification to OLD email address
    VANotifyEmailJob.perform_async(old_email.email, CONTACT_INFO_CHANGE_TEMPLATE, personalisation)
    
    # Send notification to NEW email address (if present)
    if transaction_status.new_email.present?
      VANotifyEmailJob.perform_async(
        transaction_status.new_email,
        CONTACT_INFO_CHANGE_TEMPLATE,
        personalisation
      )
    end

    old_email.destroy                                        # ← Clean up after sending
  end
end
```

**Key differences from address/phone notifications:**
- Sends to **TWO email addresses** (old and new)
- Uses `OldEmail` model instead of `TransactionNotification`
- Requires `OldEmail.find(transaction.id)` to exist (stored during `put_email`)
- Destroys the `OldEmail` record after sending notifications

---

## How Old Email is Stored

**In `put_email` method (Lines 138-155):**

```ruby
def put_email(email)
  old_email =
    begin
      @user.va_profile_email                                 # ← Get current email before update
    rescue
      nil
    end

  response = post_or_put_data(:put, email, 'emails', EmailTransactionResponse)

  transaction = response.transaction
  if transaction.received? && old_email.present?             # ← Only store if transaction received
    OldEmail.create(transaction_id: transaction.id,          #    and old email exists
                    email: old_email)
  end

  response
end
```

**Important:** 
- Old email is only stored when updating (PUT), not when creating (POST)
- Old email must be present (not blank)
- Transaction must have `received?` status

---

## Email Personalisation

The template receives personalization based on what changed:

```ruby
EMAIL_PERSONALISATIONS = {
  address: 'Address',
  residence_address: 'Home address',
  correspondence_address: 'Mailing address',
  email: 'Email address',
  phone: 'Phone number',
  home_phone: 'Home phone number',
  mobile_phone: 'Mobile phone number',
  work_phone: 'Work phone number'
}.freeze

def get_email_personalisation(type)
  { 'contact_info' => EMAIL_PERSONALISATIONS[type] }
end
```

The VANotify template receives: `{ 'contact_info' => 'Email address' }` for email changes.

---

## Models Used

### TransactionNotification
**Purpose:** Prevents duplicate notifications for address/phone changes

**Storage:** Redis (temporary)
- Namespace: `REDIS_CONFIG[:transaction_notification][:namespace]`
- TTL: `REDIS_CONFIG[:transaction_notification][:each_ttl]`
- Key: `transaction_id`

**Attributes:**
- `transaction_id` (String, required)

### OldEmail
**Purpose:** Temporarily stores the user's old email during email update process

**Storage:** Redis (temporary)
- Namespace: `REDIS_CONFIG[:old_email][:namespace]`
- TTL: `REDIS_CONFIG[:old_email][:each_ttl]`
- Key: `transaction_id`

**Attributes:**
- `transaction_id` (String, required)
- `email` (String, required)

**Lifecycle:**
1. Created in `put_email` when transaction is received
2. Retrieved in `send_email_change_notification`
3. Destroyed after sending notifications

---

## VANotifyEmailJob

**File:** `app/sidekiq/va_notify_email_job.rb`

**Note:** This class is **deprecated** in favor of `modules/va_notify/app/sidekiq/va_notify/email_job.rb`

**Current implementation:**
```ruby
def perform(email, template_id, personalisation = nil)
  notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)

  notify_client.send_email(
    **{
      email_address: email,
      template_id:,
      personalisation:
    }.compact
  )
rescue VANotify::Error => e
  if e.status_code == 400
    log_exception_to_sentry(e, ...)
    log_exception_to_rails(e)
  else
    raise e  # Will trigger Sidekiq retry
  end
end
```

**Retry policy:** 
- `sidekiq_options retry: 16`
- Retries for approximately 2 days 1 hour 47 minutes 12 seconds

---

## Complete Email Update Flow

### Scenario: User updates their email from old@example.com → new@example.com

**Step 1:** Frontend calls `PUT /v0/profile/email_addresses`

**Step 2:** Controller calls `VAProfile::ContactInformation::V2::Service#put_email`
```ruby
# Before update
old_email = "old@example.com"  # From user.va_profile_email

# Make API request to VAProfile
response = post_or_put_data(:put, email, 'emails', EmailTransactionResponse)

# If transaction.received? && old_email.present?
OldEmail.create(
  transaction_id: "abc-123",
  email: "old@example.com"
)
```

**Step 3:** Async job polls transaction status by calling `get_email_transaction_status`

**Step 4:** When transaction completes successfully:
```ruby
# Inside send_email_change_notification
old_email_record = OldEmail.find("abc-123")  # → { email: "old@example.com" }

# Send to old email
VANotifyEmailJob.perform_async(
  "old@example.com",
  CONTACT_INFO_CHANGE_TEMPLATE,
  { 'contact_info' => 'Email address' }
)

# Send to new email
VANotifyEmailJob.perform_async(
  "new@example.com",
  CONTACT_INFO_CHANGE_TEMPLATE,
  { 'contact_info' => 'Email address' }
)

old_email_record.destroy  # Clean up
```

---

## Critical Logic Points

### ✅ Email Notifications ARE Sent When:

**For Address/Phone Changes:**
1. Transaction completes successfully (`completed_success?`)
2. No previous notification sent for this transaction ID
3. User has a valid email in their VAProfile

**For Email Changes:**
1. Transaction completes successfully (`completed_success?`)
2. Old email was stored during the PUT request
3. Both old and new emails receive notifications

### ❌ Email Notifications are NOT Sent When:

**For Address/Phone Changes:**
1. Transaction fails or is still processing
2. Notification already sent for this transaction (duplicate prevention)
3. User has no email in their VAProfile

**For Email Changes:**
1. Transaction fails or is still processing
2. No old email was stored (shouldn't happen in normal flow)
3. Creating a new email (POST) instead of updating (PUT)
4. Old email was blank during update

---

## Potential Issues or Edge Cases

### 1. Email Changes for Users Without Previous Email
If a user is creating their first email (POST), they won't receive a notification because:
- `put_email` is not called (only `post_email`)
- No `OldEmail` record is created
- `send_email_change_notification` returns early when `old_email.nil?`

### 2. Race Conditions
If the transaction status is polled multiple times:
- **Address/Phone:** Protected by `TransactionNotification.find()` check
- **Email:** Protected by `OldEmail.destroy` (record deleted after first successful notification)

### 3. Redis TTL Expiration
If the Redis records expire before the transaction completes:
- **Address/Phone:** Could send duplicate notifications
- **Email:** Won't send any notification (old email lost)

### 4. Failed Email Deliveries
- VANotify 400 errors are logged but don't retry
- Other errors trigger Sidekiq retry (up to 16 times)

---

## Recent Changes (Past 3 Weeks)

⚠️ **Important Finding:**

Based on the git history available (shallow clone), the most recent commit shows:
- **Date:** December 30, 2025
- **Commit:** `e6c6680` - "Bump faraday-follow_redirects from 0.3.0 to 0.4.0"

This commit shows `lib/va_profile/contact_information/v2/service.rb` was **added** in the shallow clone, making it difficult to determine what specifically changed in the past 3 weeks.

### To investigate actual recent changes, you would need to:

1. **Check the full git history** (not shallow clone):
   ```bash
   git log --since="3 weeks ago" --patch -- lib/va_profile/contact_information/v2/service.rb
   ```

2. **Look for PRs merged in the past 3 weeks** that touched:
   - `lib/va_profile/contact_information/v2/service.rb`
   - `app/models/old_email.rb`
   - `app/models/transaction_notification.rb`
   - `app/sidekiq/va_notify_email_job.rb`

3. **Search for specific logic changes** around:
   - `send_email_change_notification` method
   - `send_contact_change_notification` method
   - Email verification callback logic
   - Transaction status polling

---

## Recommendations for Further Investigation

To understand what changed in the past 3 weeks:

1. **Check GitHub directly** for recent PRs affecting these files
2. **Review commit messages** for keywords like:
   - "email notification"
   - "contact info change"
   - "va notify"
   - "email verification"
   - "transaction notification"

3. **Look for changes to**:
   - Conditional logic in `send_email_change_notification`
   - Conditional logic in `send_contact_change_notification`
   - `OldEmail` model lifecycle
   - `TransactionNotification` duplicate prevention

4. **Check related files** that might affect email sending:
   - Email verification services
   - Profile controllers
   - VA Profile transaction polling jobs

---

## Summary

The email notification logic for contact info changes is controlled by:

1. **Two separate methods** with different logic:
   - `send_contact_change_notification` - for address/phone
   - `send_email_change_notification` - for email updates

2. **Key difference for email changes:**
   - Sends to BOTH old and new email addresses
   - Uses `OldEmail` temporary storage
   - Only works for PUT (updates), not POST (new emails)

3. **Protection mechanisms:**
   - `TransactionNotification` prevents duplicate address/phone notifications
   - `OldEmail.destroy` prevents duplicate email notifications
   - All notifications require `completed_success?` status

4. **Current limitation:** The shallow git clone prevents detailed analysis of what changed in the past 3 weeks. A full git history or GitHub PR review would be needed to identify specific logic modifications.

