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

puts "Making sure Flipper for creating VANotify::Notification records is on..."
Flipper.enable(:va_notify_notification_creation) unless Flipper.enabled?(:va_notify_notification_creation)

# Check prerequisites
user_account = UserAccount.first
if user_account.nil?
  UserAccount.create!(icn: SecureRandom.uuid)
  user_account = UserAccount.first
end

puts "✅ Using UserAccount: #{user_account.id}"

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
            "email" => "test_email_#{index + 1}@gmail.com",
            "firstName" => "Test",
            "lastName" => "Veteran#{index + 1}"
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
uploads = appeal_submissions.first(2).flat_map.with_index do |submission, submission_index|
  2.times.map do |upload_index|
    guid = SecureRandom.uuid
    filename = "test_document_#{submission_index}_#{upload_index}.pdf"

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
end

puts "   Created #{uploads.count} AppealSubmissionUploads"

# 4. Create SecondaryAppealForms
puts "📄 Creating SecondaryAppealForms..."
secondary_forms = appeal_submissions.last(2).map.with_index do |submission, index|
  SecondaryAppealForm.create!(
    guid: SecureRandom.uuid,
    form_id: "4142",
    form: {
      "data" => {
        "formId" => "4142",
        "veteran" => {
          "firstName" => "Test",
          "lastName" => "Veteran"
        }
      }
    }.to_json,
    appeal_submission: submission,
    status: "submitted",
    failure_notification_sent_at: nil,
    delete_date: nil
  )
end

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
  submission_with_uploads = uploads.first.appeal_submission
  saved_claim_with_uploads = SavedClaim.find_by(guid: submission_with_uploads.submitted_appeal_uuid)
  
  if saved_claim_with_uploads
    # Update email
    form_data = JSON.parse(saved_claim_with_uploads.form)
    form_data['data']['attributes']['veteran']['email'] = "test.evidence.error@example.com"
    

    # Create upload errors in metadata
    upload_errors = uploads.select { |u| u.appeal_submission == submission_with_uploads }.map do |upload|
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
      form: form_data.to_json,
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
    form_data['data']['attributes']['veteran']['email'] = "test.secondary.form#{index + 1}@example.com"
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
  submissions.each { |s| puts "   Form #{s.id}: #{s.current_email_address}" }
  submission_uploads.each { |u| puts "   Upload #{u.lighthouse_upload_id}: #{u.appeal_submission.current_email_address}" }
  errored_secondary_forms.each { |f| puts "   Secondary #{f.id}: #{f.appeal_submission.current_email_address}" }
  
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

5. You should see 7 VANotify::Notification records created corresponding to each of the "emails" sent by entering the following query:
`VANotify::Notication.count`
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
      request.body = { id: id, notification_type: "email", status: "delivered", completed_at: "2025-07-28T12:00:00Z" }.to_json

      response = http.request(request)
      puts "Request #{index + 1} - Status: #{response.code}, Body: #{response.body}"
    end
  end
end
```
11. Before running, you should see 0 DecisionReviewNotificationAuditLog records
12. Execute by running `trigger_va_notify_callbacks`
13. Go to the tab running your local rails server. On the first breakpoint, execute `Rails.application.eager_load!`. After the classes are loaded, continue through the breakpoints. You should see successful log messages.
14. Go back to the tab running your rails console and check the `DecisionReviewNotificationAuditLog` table. You should see 7 records corresponding to the emails. For example:
```
vets-api(dev)> DecisionReviewNotificationAuditLog.all.pluck(:status, :reference)
=> 
[["delivered", "HLR-form-83870cee-56fb-4ee5-9963-2aef2c052759"],
 ["delivered", "NOD-form-eeaa4304-bbd4-488b-95a8-35674f0ad30f"],
 ["delivered", "SC-form-8556ab91-93b9-4776-9179-d753118ca250"],
 ["delivered", "HLR-evidence-f2be1302-be5f-4bfa-aff5-e94aa51e5b4d"],
 ["delivered", "HLR-evidence-93104a43-ae59-45fd-a36c-0e59d79f6449"],
 ["delivered", "NOD-secondary_form-00f818a9-741e-41c7-868d-326b35d4a20d"],
 ["delivered", "SC-secondary_form-f0481149-2cea-402a-bd5f-05b8ff6e9924"]]
```