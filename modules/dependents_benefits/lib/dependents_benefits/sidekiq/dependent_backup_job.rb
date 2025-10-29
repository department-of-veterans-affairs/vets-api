# frozen_string_literal: true

require 'central_mail/service'
require 'benefits_intake_service/service'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_info'
require 'simple_forms_api_submission/metadata_validator'

module DependentsBenefits::Sidekiq
  class DependentBackupJob < DependentSubmissionJob
    include Sidekiq::Job

    ##
    # Service-specific submission logic for Lighthouse upload
    # @return [ServiceResponse] Must respond to success? and error methods
    def submit_to_service
      lighthouse_submission = DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim, user_data)
      @uuid = lighthouse_submission.initialize_service
      update_submission_attempt_uuid
      lighthouse_submission.prepare_submission
      lighthouse_submission.upload_to_lh
      DependentsBenefits::ServiceResponse.new(status: true)
    rescue => e
      DependentsBenefits::ServiceResponse.new(status: false, error: e)
    ensure
      lighthouse_submission.cleanup_file_paths
    end

    def handle_permanent_failure(msg, error)
      @claim_id = msg['args'].first
      send_failure_notification
      monitor.log_silent_failure_avoided({ claim_id:, error: })
    rescue => e
      # Last resort if notification fails
      monitor.log_silent_failure({ claim_id:, error: e })
    end

    # Atomic updates prevent partial state corruption
    def handle_job_success
      ActiveRecord::Base.transaction do
        parent_group.with_lock do
          mark_submission_succeeded # update attempt and submission records (ie FormSubmission)

          # update parent claim group status - overwrite failure since we're in backup job
          # the parent group is marked as processing to indicate it hasn't reached VBMS yet
          mark_parent_group_processing
          # notify user of acceptance by the service - final success will be sent after VBMS is reached
          send_in_progress_notification
        end
      end
    rescue => e
      monitor.track_submission_error('Error handling job success', 'success_failure', error: e)
    end

    private

    def saved_claim = @saved_claim ||= DependentsBenefits::SavedClaim.find(claim_id)

    def uuid = @uuid || nil

    def find_or_create_form_submission
      @submission = Lighthouse::Submission.find_or_create_by!(saved_claim_id: saved_claim.id) do |submission|
        submission.assign_attributes({ form_id: saved_claim.form_id, reference_data: saved_claim.to_json })
      end
    end

    def create_form_submission_attempt
      @submission_attempt = Lighthouse::SubmissionAttempt.create(submission:, benefits_intake_uuid: uuid)
    end

    def update_submission_attempt_uuid
      submission_attempt&.update(benefits_intake_uuid: @uuid)
    end

    # Service-specific success logic
    # Update submission attempt and form submission records
    def mark_submission_succeeded = submission_attempt&.success!

    # Service-specific failure logic
    # Update submission attempt record only with failure and error details
    def mark_submission_attempt_failed(_exception) = submission_attempt&.fail!

    # Lighthouse submission has no status update, so no-op here
    def mark_submission_failed(_exception) = nil

    # We don't care about parent group status in backup job
    def parent_group_failed? = false
  end
end
