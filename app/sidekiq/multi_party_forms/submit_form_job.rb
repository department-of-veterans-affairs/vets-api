# frozen_string_literal: true

require 'vets/shared_logging'

module MultiPartyForms
  class SubmitFormJob
    include Sidekiq::Job
    include Vets::SharedLogging

    class MergeServiceNotFoundError < StandardError; end
    class MissingFormDataError < StandardError; end

    RETRY = 10
    STATSD_KEY_PREFIX = 'worker.multi_party_forms.submit_form'

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      submission_id = msg['args'].first
      Rails.logger.error(
        'MultiPartyForms::SubmitFormJob failed, retries exhausted!',
        { submission_id:, error: msg['error_message'] }
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    def perform(submission_id)
      Rails.logger.info('MultiPartyForms::SubmitFormJob running!', { submission_id: })
      StatsD.increment("#{STATSD_KEY_PREFIX}.begin")

      @submission = MultiPartyFormSubmission.find(submission_id)
      build_and_associate_saved_claim
      enqueue_lighthouse_submission
      enqueue_confirmation_emails
      cleanup_in_progress_forms

      Rails.logger.info('MultiPartyForms::SubmitFormJob succeeded!', { submission_id: })
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    rescue => e
      handle_error(e, submission_id)
      raise
    end

    private

    def build_and_associate_saved_claim
      return if @submission.saved_claim_id.present?

      ActiveRecord::Base.transaction do
        merged_data = merge_form_data
        saved_claim = create_saved_claim(merged_data)
        @submission.update!(saved_claim:)
      end
    end

    def handle_error(error, submission_id)
      Rails.logger.error(
        'MultiPartyForms::SubmitFormJob failed, retrying...',
        { submission_id:, error: error.message, backtrace: error.backtrace&.first(5) }
      )
      log_exception_to_sentry(error, { submission_id: })
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
    end

    def merge_form_data
      primary_data = @submission.primary_in_progress_form.form_data
      secondary_data = @submission.secondary_in_progress_form.form_data

      raise MissingFormDataError, "Missing primary form data for submission #{@submission.id}" if primary_data.nil?
      raise MissingFormDataError, "Missing secondary form data for submission #{@submission.id}" if secondary_data.nil?

      resolve_merge_service.new(primary_data, secondary_data).merge
    end

    def resolve_merge_service
      base_form_type = @submission.form_type.sub(/-(PRIMARY|SECONDARY)$/, '')
      form_key = "Form#{base_form_type.delete('^A-Za-z0-9')}"
      "MultiPartyForms::#{form_key}::MergeService".constantize
    rescue NameError
      raise MergeServiceNotFoundError, "No MergeService found for form type: #{@submission.form_type}"
    end

    def create_saved_claim(merged_data)
      SavedClaim.create!(
        form_id: @submission.form_type.sub(/-(PRIMARY|SECONDARY)$/, ''),
        form_data: merged_data.to_json
      )
    end

    def enqueue_lighthouse_submission
      return if @submission.submitted_at.present?

      @submission.update!(submitted_at: Time.zone.now)
      Lighthouse::SubmitBenefitsIntakeClaim.perform_async(@submission.saved_claim_id)
    rescue
      @submission.update!(submitted_at: nil)
      raise
    end

    def enqueue_confirmation_emails
      # TODO: Enqueue confirmation email jobs for both parties once jobs are implemented
      # MultiPartyForms::SendConfirmationEmailJob.perform_async(@submission.id, 'primary')
      # MultiPartyForms::SendConfirmationEmailJob.perform_async(@submission.id, 'secondary')
    end

    def cleanup_in_progress_forms
      @submission.primary_in_progress_form&.destroy
      @submission.secondary_in_progress_form&.destroy
    end
  end
end
