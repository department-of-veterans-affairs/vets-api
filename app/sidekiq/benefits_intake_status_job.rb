# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
require 'pcpg/monitor'
require 'dependents/monitor'
require 'vre/vre_monitor'

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
    StatsD.increment("#{STATS_KEY}.job.started")
    Rails.logger.info('BenefitsIntakeStatusJob started')

    begin
      process_pending_submissions
    rescue => e
      handle_job_failure(e)
      raise
    end
  end

  private

  def process_pending_submissions
    pending_form_submission_attempts = fetch_pending_attempts

    total_handled, result = batch_process(pending_form_submission_attempts)

    record_job_result(result, total_handled)
  end

  def fetch_pending_attempts
    pending_attempts = FormSubmissionAttempt.where(aasm_state: 'pending')
                                            .includes(:form_submission).to_a

    form_ids = BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS.keys.map(&:to_s)
    pending_attempts.reject { |pfsa| form_ids.include?(pfsa.form_submission.form_type) }
  end

  def record_job_result(result, total_handled)
    if result
      StatsD.increment("#{STATS_KEY}.job.completed")
      Rails.logger.info('BenefitsIntakeStatusJob ended', total_handled:)
    else
      StatsD.increment("#{STATS_KEY}.job.failed")
    end
  end

  def handle_job_failure(exception)
    StatsD.increment("#{STATS_KEY}.job.failed")
    Rails.logger.error('BenefitsIntakeStatusJob failed with exception',
                       class: self.class.name,
                       message: exception.message)
  end

  def batch_process(pending_form_submission_attempts)
    total_handled = 0
    errors = []
    intake_service = BenefitsIntake::Service.new

    pending_form_submission_attempts.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      response = intake_service.bulk_status(uuids: batch_uuids)

      # Log the entire response for debugging purposes
      Rails.logger.info("Received bulk status response: #{response.body}")

      errors << response.body unless response.success?

      total_handled += handle_response(response)
    end

    unless errors.empty?
      Rails.logger.error('Errors occurred while processing Intake Status batch', class: self.class.name,
                                                                                 errors:)
    end

    [total_handled, true]
  rescue => e
    Rails.logger.error('Benefits Intake Status Job failed, some batched submissions may not have been processed',
                       class: self.class.name, message: e.message)
    [total_handled, false]
  end

  # rubocop:disable Metrics/MethodLength
  def handle_response(response)
    total_handled = 0

    # Ensure response body contains data, and log the data for debugging
    if response.body['data'].blank?
      Rails.logger.error("Response data is blank or missing: #{response.body}")
      return total_handled
    end

    response.body['data']&.each do |submission|
      uuid = submission['id']
      form_submission_attempt = form_submission_attempts_hash[uuid]
      form_submission = form_submission_attempt&.form_submission
      form_id = form_submission&.form_type
      saved_claim_id = form_submission&.saved_claim_id
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
        monitor_failure(form_id, saved_claim_id, uuid)
      elsif status == 'error'
        # Error - Indicates that there was an error. Refer to the error code and detail for further information.
        error_message = "#{submission.dig('attributes', 'code')}: #{submission.dig('attributes', 'detail')}"
        form_submission_attempt.update(error_message:, lighthouse_updated_at:)
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition, error_message)
        monitor_failure(form_id, saved_claim_id, uuid)
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

  # rubocop:disable Metrics/MethodLength
  def monitor_failure(form_id, saved_claim_id, bi_uuid)
    context = {
      form_id:,
      claim_id: saved_claim_id,
      benefits_intake_uuid: bi_uuid
    }
    call_location = caller_locations.first

    # Dependents
    if %w[686C-674 686C-674-V2 21-674 21-674-V2].include?(form_id)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      email = if claim.present?
                claim.parsed_form.dig('dependents_application', 'veteran_contact_information', 'email_address')
              end
      if claim.present? && email.present?
        claim.send_failure_email(email)
        claim.monitor.log_silent_failure_no_confirmation(context, call_location:)
      else
        monitor = claim.present? ? claim.monitor : Dependents::Monitor.new(false)
        monitor.log_silent_failure(context, call_location:)
      end
    end

    # PCPG
    if %w[28-8832].include?(form_id)
      claim = SavedClaim::EducationCareerCounselingClaim.find(saved_claim_id)
      email = claim.parsed_form.dig('claimantInformation', 'emailAddress') if claim.present?
      if claim.present? && email.present?
        claim.send_failure_email(email)
        PCPG::Monitor.new.log_silent_failure_no_confirmation(context, call_location:)
      else
        PCPG::Monitor.new.log_silent_failure(context, call_location:)
      end
    end

    # VRE
    if %w[28-1900].include?(form_id)
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find(saved_claim_id)
      email = claim.parsed_form['email'] if claim.present?
      if claim.present? && email.present?
        claim.send_email(:error)
        VRE::VREMonitor.new.log_silent_failure_avoided(context, call_location:)
      else
        VRE::VREMonitor.new.log_silent_failure(context, call_location:)
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def form_submission_attempts_hash
    @_form_submission_attempts_hash ||= FormSubmissionAttempt
                                        .where(aasm_state: 'pending')
                                        .index_by(&:benefits_intake_uuid)
  end
end
