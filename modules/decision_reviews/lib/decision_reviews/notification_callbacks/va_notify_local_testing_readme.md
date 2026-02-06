## Testing DecisionReviews::FailureNotificationEmailJob + VA Notify Callbacks Locally

This guide walks through how to test decision review failure notification emails and VA Notify callbacks E2E locally.


### !!! PREREQUISITES !!!
1. Update the personalisation object on line 113 in FailureNotificationEmailJob with a static first_name (DO NOT COMMIT THIS CHANGE!!). This is so we can avoid mocking the mpi_profile service which currently doesn't provide mocks.
2. Update the create_notification method in `VANotify::Service` to use `SecureRandom.uuid` for the `notification_id`, line 116 (DO NOT COMMIT THIS CHANGE!!). This is because the betamocks default response uses a static uuid for `notification_id`, so we want to override it here (for testing) to ensure that each notification gets a unique identifier.
3. Update your `settings.local.yml` to include the following:

```
vanotify:
  mock: true # This will enable betamocked responses
  services:
    benefits_decision_review:
      api_key: <api-key> # Grab from Argo vets-api-staging
```

4. Open up rails console (bundle exec rails console) and copy paste the following script

```
puts "🚀 Setting up test data for FailureNotificationEmailJob..."

# ⚠️ UPDATE THIS EMAIL TO YOUR PERSONAL EMAIL FOR TESTING ⚠️
TEST_EMAIL = "your-email@example.com"

# Staging test veteran (Hector Allen)
TEST_ICN = "1012667122V019349"
TEST_VETERAN = { first_name: "Hector", last_name: "Allen" }.freeze

# Check prerequisites - use a known staging ICN
user_account = UserAccount.find_by(icn: TEST_ICN)
if user_account.nil?
  user_account = UserAccount.create!(icn: TEST_ICN)
end

puts "✅ Using UserAccount: #{user_account.id} (ICN: #{user_account.icn})"
puts "✅ Test veteran: #{TEST_VETERAN[:first_name]} #{TEST_VETERAN[:last_name]}"
puts "✅ Test email: #{TEST_EMAIL}"

# 1. Create SavedClaims with proper types and form data
puts "📝 Creating SavedClaims..."
appeal_types = [
  'SavedClaim::HigherLevelReview',
  'SavedClaim::NoticeOfDisagreement',
  'SavedClaim::SupplementalClaim'
]

saved_claims = appeal_types.map.with_index do |type, index|
  SavedClaim.create!(
    type: type,
    guid: SecureRandom.uuid,
    user_account: user_account,
    form: {
      "data" => {
        "attributes" => {
          "veteran" => {
            "email" => TEST_EMAIL,
            "firstName" => TEST_VETERAN[:first_name],
            "lastName" => TEST_VETERAN[:last_name]
          },
          "appealType" => type.split('::').last
        }
      }
    }.to_json,
    metadata: { "status" => "submitted" }.to_json,
    delete_date: nil
  )
end

puts "   Created #{saved_claims.count} SavedClaims"

# 2. Create AppealSubmissions linked to SavedClaims
puts "📋 Creating AppealSubmissions..."
type_mapping = {
  'SavedClaim::HigherLevelReview' => 'HLR',
  'SavedClaim::NoticeOfDisagreement' => 'NOD',
  'SavedClaim::SupplementalClaim' => 'SC'
}

appeal_submissions = saved_claims.map do |saved_claim|
  AppealSubmission.create!(
    submitted_appeal_uuid: saved_claim.guid,
    type_of_appeal: type_mapping[saved_claim.type],
    user_account: user_account,
    failure_notification_sent_at: nil
  )
end

puts "   Created #{appeal_submissions.count} AppealSubmissions"

# 3. Create AppealSubmissionUploads for evidence testing
puts "📎 Creating AppealSubmissionUploads..."
uploads = appeal_submissions.last(2).flat_map.with_index do |submission, submission_index|
  guid = SecureRandom.uuid
  filename = "test_document_#{submission_index}.pdf"

  # Create the DecisionReviewEvidenceAttachment without validation
  attachment = DecisionReviewEvidenceAttachment.new(
    guid: guid,
    file_data: {
      "filename" => filename,
      "size" => 1024,
      "content_type" => "application/pdf"
    }.to_json
  )

  # Skip validation to avoid file existence checks
  attachment.save!(validate: false)

  AppealSubmissionUpload.create!(
    appeal_submission: submission,
    decision_review_evidence_attachment_guid: guid,
    lighthouse_upload_id: guid,  # Set both to same value for consistency
    failure_notification_sent_at: nil
  )
end

puts "   Created #{uploads.count} AppealSubmissionUploads"

# 4. Create SecondaryAppealForms
puts "📄 Creating SecondaryAppealForms..."
secondary_forms = [SecondaryAppealForm.create!(
    guid: SecureRandom.uuid,
    form_id: "4142",
    form: {
      "data" => {
        "formId" => "4142",
        "veteran" => {
          "firstName" => TEST_VETERAN[:first_name],
          "lastName" => TEST_VETERAN[:last_name]
        }
      }
    }.to_json,
    appeal_submission: appeal_submissions.last,
    status: "submitted",
    failure_notification_sent_at: nil,
    delete_date: nil
  )]

puts "   Created #{secondary_forms.count} SecondaryAppealForms"

# 5. Set up ERROR CONDITIONS
puts "⚠️  Setting up error conditions..."

# Update emails and set form errors (one for each type of claim)
saved_claims.first(3).each_with_index do |saved_claim, index|
  # Set error metadata
  error_metadata = {
    "status" => "error",
    "error_message" => "Test form submission failed #{index + 1}",
    "test_scenario" => true
  }

  saved_claim.update!(
    metadata: error_metadata.to_json,
    delete_date: nil
  )
end

puts "   Set up form errors for 2 SavedClaims"

# Set up evidence errors (for submission with uploads)
if uploads.any?
  submissions_with_uploads = uploads.map(&:appeal_submission)
  saved_claims_with_uploads = SavedClaim.where(guid: submissions_with_uploads.pluck(:submitted_appeal_uuid))

  saved_claims_with_uploads.each do |saved_claim_with_uploads|
    # Create upload errors in metadata
    upload_errors = uploads.map do |upload|
      {
        "id" => upload.lighthouse_upload_id,
        "status" => "error",
        "error_message" => "Test evidence upload failed"
      }
    end

    # Combined form + evidence errors
    combined_metadata = {
      "status" => "error",
      "error_message" => "Test form and evidence failed",
      "uploads" => upload_errors,
      "test_scenario" => true
    }

    saved_claim_with_uploads.update!(
      metadata: combined_metadata.to_json,
      delete_date: nil
    )

    puts "   Set up evidence errors for #{upload_errors.count} uploads"
  end
end

# Set up secondary form errors
secondary_forms.each_with_index do |form, index|
  # Update secondary form status
  form.update!(
    status: "error - test secondary form failure #{index + 1}",
    failure_notification_sent_at: nil,
    delete_date: nil
  )

  # Update email in associated SavedClaim
  appeal_submission = form.appeal_submission
  saved_claim = SavedClaim.find_by(guid: appeal_submission.submitted_appeal_uuid)

  if saved_claim
    form_data = JSON.parse(saved_claim.form)
    form_data['data']['attributes']['veteran']['email'] = TEST_EMAIL
    saved_claim.update!(form: form_data.to_json)
  end
end

puts "   Set up secondary form errors for #{secondary_forms.count} forms"

# Reset all notification timestamps
AppealSubmission.update_all(failure_notification_sent_at: nil)
AppealSubmissionUpload.update_all(failure_notification_sent_at: nil)
SecondaryAppealForm.update_all(failure_notification_sent_at: nil)

# 7. Verification
puts "🔍 Verifying setup..."
job = DecisionReviews::FailureNotificationEmailJob.new

begin
  submissions = job.send(:submissions)
  submission_uploads = job.send(:submission_uploads)
  errored_secondary_forms = job.send(:errored_secondary_forms)

  puts "\n📊 Job will process:"
  puts "   - #{submissions.count} form submissions"
  puts "   - #{submission_uploads.count} evidence uploads"
  puts "   - #{errored_secondary_forms.count} secondary forms"

  # Show email addresses
  puts "\n📧 Notification emails:"
  submissions.each { |s| puts "   Form #{s.id} #{s.type_of_appeal}: #{s.current_email_address}" }
  submission_uploads.each { |u| puts "   Upload #{u.lighthouse_upload_id} from AppealSubmission id #{u.appeal_submission.id}" }
  errored_secondary_forms.each { |f| puts "   Secondary #{f.id} from AppealSubmission id #{f.appeal_submission.id}: #{f.appeal_submission.current_email_address}" }

  if submissions.count > 0 || submission_uploads.count > 0 || errored_secondary_forms.count > 0
    puts "\n✅ SUCCESS! Test data ready for job execution"
    puts "\nTo run the job:"
    puts "   job = DecisionReviews::FailureNotificationEmailJob.new"
    puts "   job.perform"
    puts "\nTo check results after running:"
    puts "   puts \"Form notifications: \#{AppealSubmission.where.not(failure_notification_sent_at: nil).count}\""
    puts "   puts \"Evidence notifications: \#{AppealSubmissionUpload.where.not(failure_notification_sent_at: nil).count}\""
    puts "   puts \"Secondary notifications: \#{SecondaryAppealForm.where.not(failure_notification_sent_at: nil).count}\""
  else
    puts "\n❌ ERROR: No records found for processing. Check the setup."
  end

rescue => e
  puts "\n❌ ERROR during verification: #{e.message}"
  puts "Check your job implementation and model relationships."
end

puts "\n🎯 Test data setup complete! Run job.perform to continue testing"
```

5. You should see 6 VANotify::Notification records created corresponding to each of the "emails" sent:
```
vets-api(dev)> VANotify::Notification.count
=> 6
vets-api(dev)> VANotify::Notification.pluck(:callback_metadata).map { |n| n["reference"] }
=>
["HLR-form-3e3c3504-497a-472f-bec0-51d61b2c4be5",
 "NOD-form-5e9baa46-3d37-4f72-aa2e-cbc7e7c0dff1",
 "SC-form-c1dc8745-9b0a-42a1-9dd5-c54ba3a3f635",
 "NOD-evidence-8ce29fcf-23f6-4570-ac02-d5aa93e4fbe4",
 "SC-evidence-e748d5d9-410e-40ec-9faa-38e850aed714",
 "SC-secondary_form-c3dc1d11-8172-4a7b-b33a-6120669f7331"]
```
6. Note: If you need to reset your database for whatever reason you can exit the console and run `bundle exec rails db:reset` Note this will drop and recreate ALL local databases!!
7. Now you can trigger callbacks for the "delivered" notifications.
8. MORE PREREQUISITES!! Make sure your local vets-api server is running in a separate tab first.
9. You'll also have to add a breakpoint (`binding.pry`) in the VANotify callbacks_controller.rb file's create method (e.g. right after line 16) so you can force eager loading (to avoid `uninitialized constant DecisionReviews::Form/EvidenceNotificationCallback errors`). Just go to the tab running your rails server process and enter the following once when the first breakpoint is hit:
`Rails.application.eager_load!`
10. Copy paste the following method into Rails console:
```
def trigger_va_notify_callbacks
  url = URI('http://localhost:3000/va_notify/callbacks')

  ids = VANotify::Notification.all.pluck(:notification_id)

  # Reuse the same HTTP connection
  Net::HTTP.start(url.host, url.port) do |http|
    ids.each_with_index do |id, index|
      request = Net::HTTP::Post.new(url)
      request['Authorization'] = 'Bearer fake_bearer_token'
      request['Content-Type'] = 'application/json'
      request.body = { id: id, notification_type: "email", status: "delivered", completed_at: Time.current.iso8601 }.to_json

      response = http.request(request)
      puts "Request #{index + 1} - Status: #{response.code}, Body: #{response.body}"
    end
  end
end
```
11. Before running, you should see 0 DecisionReviewNotificationAuditLog records
12. Execute by running `trigger_va_notify_callbacks`
13. Go to the tab running your local rails server. On the first breakpoint, execute `Rails.application.eager_load!`. After the classes are loaded, continue through the breakpoints. You should see successful log messages.
14. Go back to the tab running your rails console and check the `DecisionReviewNotificationAuditLog` table. You should see 6 records corresponding to the emails. For example:
```
vets-api(dev)> DecisionReviewNotificationAuditLog.all.pluck(:status, :reference)
=>
[["delivered", "HLR-form-3e3c3504-497a-472f-bec0-51d61b2c4be5"],
 ["delivered", "NOD-form-5e9baa46-3d37-4f72-aa2e-cbc7e7c0dff1"],
 ["delivered", "SC-form-c1dc8745-9b0a-42a1-9dd5-c54ba3a3f635"],
 ["delivered", "NOD-evidence-8ce29fcf-23f6-4570-ac02-d5aa93e4fbe4"],
 ["delivered", "SC-evidence-e748d5d9-410e-40ec-9faa-38e850aed714"],
 ["delivered", "SC-secondary_form-c3dc1d11-8172-4a7b-b33a-6120669f7331"]]
```