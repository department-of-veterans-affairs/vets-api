# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

# Datadog Dashboard:
# https://vagov.ddog-gov.com/dashboard/4d8-3fn-dbp/benefits-intake-form-submission-tracking?fromUser=false&refresh_mode=sliding&view=spans&from_ts=1717772535566&to_ts=1718377335566&live=true
class BenefitsIntakeStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
  BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

  attr_reader :batch_size

  def initialize(batch_size: BATCH_SIZE)
    @batch_size = batch_size
  end

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    form_submissions_and_attempts = FormSubmission.joins(:form_submission_attempts)
    resolved_form_submission_ids = form_submissions_and_attempts
                                   .where(form_submission_attempts: { aasm_state: %w[vbms failure] })
                                   .pluck(:id)
    pending_form_submissions = form_submissions_and_attempts
                               .where(form_submission_attempts: { aasm_state: 'pending' })
                               .where.not(id: resolved_form_submission_ids)
    # We're calculating the resolved_form_submissions and removing them because it is possible for a FormSubmission
    # to have two (or more) attempts, one 'pending' and the other 'vbms'. In such cases we don't want to include
    # that FormSubmission because it has been resolved.
    total_handled, result = batch_process(pending_form_submissions)
    Rails.logger.info('BenefitsIntakeStatusJob ended', total_handled:) if result
  end

  private

  def batch_process(pending_form_submissions)
    total_handled = 0
    intake_service = BenefitsIntake::Service.new

    pending_form_submissions.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      response = intake_service.bulk_status(uuids: batch_uuids)

      # Log the entire response for debugging purposes
      Rails.logger.info("Received bulk status response: #{response.body}")

      raise response.body unless response.success?

      total_handled += handle_response(response, batch)
    end

    [total_handled, true]
  rescue => e
    Rails.logger.error('Error processing Intake Status batch', class: self.class.name, message: e.message)
    [total_handled, false]
  end

  # rubocop:disable Metrics/MethodLength
  def handle_response(response, pending_form_submissions)
    total_handled = 0

    # Ensure response body contains data, and log the data for debugging
    if response.body['data'].blank?
      Rails.logger.error("Response data is blank or missing: #{response.body}")
      return total_handled
    end

    response.body['data']&.each do |submission|
      uuid = submission['id']
      form_submission = pending_form_submissions.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == uuid
      end
      form_id = form_submission.form_type

      form_submission_attempt = form_submission.latest_pending_attempt
      time_to_transition = (Time.zone.now - form_submission_attempt.created_at).truncate

      # https://developer.va.gov/explore/api/benefits-intake/docs
      status = submission.dig('attributes', 'status')

      # Log the status for debugging
      Rails.logger.info("Processing submission UUID: #{uuid}, Status: #{status}")

      lighthouse_updated_at = submission.dig('attributes', 'updated_at')
      if status == 'expired'
        # Expired - Indicate that documents were not successfully uploaded within the 15-minute window.
        error_message = 'expired'
        form_submission_attempt.update(error_message:, lighthouse_updated_at:)
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition, error_message)
      elsif status == 'error'
        # Error - Indicates that there was an error. Refer to the error code and detail for further information.
        error_message = "#{submission.dig('attributes', 'code')}: #{submission.dig('attributes', 'detail')}"
        form_submission_attempt.update(error_message:, lighthouse_updated_at:)
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition, error_message)
      elsif status == 'vbms'
        # submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.update(lighthouse_updated_at:)
        form_submission_attempt.vbms!
        log_result('success', form_id, uuid, time_to_transition)
      elsif time_to_transition > STALE_SLA.days
        # exceeds SLA (service level agreement) days for submission completion
        log_result('stale', form_id, uuid, time_to_transition)
      else
        # no change being tracked
        log_result('pending', form_id, uuid)
        Rails.logger.info(
          "Submission UUID: #{uuid} is still pending, status: #{status}, time to transition: #{time_to_transition}"
        )
      end

      total_handled += 1
    end

    total_handled
  end
  # rubocop:enable Metrics/MethodLength

  def log_result(result, form_id, uuid, time_to_transition = nil, error_message = nil)
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
    if result == 'failure'
      Rails.logger.error('BenefitsIntakeStatusJob', result:, form_id:, uuid:, time_to_transition:, error_message:)
    else
      Rails.logger.info('BenefitsIntakeStatusJob', result:, form_id:, uuid:, time_to_transition:)
    end
  end
end
