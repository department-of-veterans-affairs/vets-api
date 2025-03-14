# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
require 'pcpg/monitor'
require 'dependents/monitor'
require 'vre/monitor'

# Datadog Dashboard:
# https://vagov.ddog-gov.com/dashboard/4d8-3fn-dbp/benefits-intake-form-submission-tracking?fromUser=false&refresh_mode=sliding&view=spans&from_ts=1717772535566&to_ts=1718377335566&live=true
class BenefitsIntakeStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
  BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000
  FORM_IDS = BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS.keys.map(&:to_s)
  DEFAULTS = {
    '686C-674' => {
      claim: SavedClaim::DependencyClaim,
      monitor: Dependents::Monitor,
      email_keys: %w[dependents_application veteran_contact_information email_address]
    },
    '28-8832' => {
      claim: SavedClaim::EducationCareerCounselingClaim,
      monitor: PCPG::Monitor,
      email_keys: %w[claimantInformation emailAddress]
    },
    '28-1900' => {
      claim: SavedClaim::VeteranReadinessEmploymentClaim,
      monitor: VRE::Monitor,
      email_keys: ['email']
    }
  }.freeze

  attr_reader :batch_size

  def initialize(batch_size: BATCH_SIZE)
    @batch_size = batch_size
  end

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    pending_form_submission_attempts = FormSubmissionAttempt.where(aasm_state: 'pending')
                                                            .includes(:form_submission).to_a

    form_ids = BenefitsIntake::SubmissionStatusJob::FORM_HANDLERS.keys.map(&:to_s)
    pending_form_submission_attempts.reject! { |pfsa| form_ids.include?(pfsa.form_submission.form_type) }

    total_handled, result = batch_process(pending_form_submission_attempts)
    Rails.logger.info('BenefitsIntakeStatusJob ended', total_handled:) if result
  end

  private

  def batch_process(pending_form_submission_attempts)
    total_handled = 0
    errors = []
    intake_service = BenefitsIntake::Service.new

    pending_form_submission_attempts.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      response = intake_service.bulk_status(uuids: batch_uuids)

      # Log the entire response for debugging purposes
      Rails.logger.info("Received bulk status response: #{response.body}")

      unless response.success?
        errors << response.body
        next
      end

      total_handled += handle_response(response, batch)
    end

    log_errors(errors) unless errors.empty?

    [total_handled, true]
  rescue => e
    Rails.logger.error('Benefits Intake Status Job failed', exception: e.message, backtrace: e.backtrace)
    [total_handled, false]
  end

  def handle_response(response, batch)
    0.tap do |total_handled|
      form_submission_attempts_by_uuid = batch.index_by(&:benefits_intake_uuid)

      (response.body['data'] || []).each do |response_submission|
        total_handled += handle_submission(response_submission, form_submission_attempts_by_uuid)
      end
    end
  end

  # https://developer.va.gov/explore/api/benefits-intake/docs
  def handle_submission(response_submission, form_submission_attempts_by_uuid)
    uuid = response_submission['id']
    form_submission_attempt = form_submission_attempts_by_uuid[uuid]
    return 0 unless form_submission_attempt

    form_submission = form_submission_attempt.form_submission
    form_id = form_submission&.form_type
    saved_claim_id = form_submission&.saved_claim_id

    process_submission_by_status(response_submission, form_submission_attempt, form_id, uuid, saved_claim_id)

    1
  end

  # rubocop:disable Metrics/MethodLength
  def process_submission_by_status(response_submission, form_submission_attempt, form_id, uuid, saved_claim_id)
    time_to_transition = (Time.zone.now - form_submission_attempt.created_at).truncate
    status = response_submission.dig('attributes', 'status')
    lighthouse_updated_at = response_submission.dig('attributes', 'updated_at')

    case status
    # Expired - Indicates that documents were not successfully uploaded within the 15-minute window.
    # Error - Indicates that there was an error. Refer to the error code and detail for further information.
    when 'expired', 'error'
      error_message = if status == 'expired'
                        'expired'
                      else
                        "#{response_submission.dig('attributes', 'code')}: " \
                          "#{response_submission.dig('attributes', 'detail')}"
                      end
      form_submission_attempt.update(error_message:, lighthouse_updated_at:)
      form_submission_attempt.fail!
      log_result('failure', form_id, uuid, time_to_transition, error_message)
      monitor_failure(form_id, saved_claim_id, uuid)
    # VBMS - Indicates that the response_submission was successfully uploaded into a Veteran's eFolder within VBMS.
    when 'vbms'
      form_submission_attempt.update(lighthouse_updated_at:)
      form_submission_attempt.vbms!
      log_result('success', form_id, uuid, time_to_transition)
    else
      log_result(time_to_transition > STALE_SLA.days ? 'stale' : 'pending', form_id, uuid, time_to_transition)
    end
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

  def monitor_failure(form_id, claim_id, benefits_intake_uuid)
    return unless claim_id

    context = { form_id:, claim_id:, benefits_intake_uuid: }
    call_location = caller_locations.first
    monitor_by_form_id(form_id, claim_id, context, call_location)
  end

  def monitor_by_form_id(form_id, saved_claim_id, context, call_location)
    claim_class = DEFAULTS[:claim][form_id]
    monitor = DEFAULTS[:monitor][form_id]&.new

    return unless claim_class && monitor

    claim = claim_class.find(saved_claim_id)
    email = claim&.parsed_form&.dig(*DEFAULTS[:email_keys][form_id] || [])

    if claim && email
      claim.send_failure_email(email)
      monitor.log_silent_failure_avoided(context, nil, call_location:)
    else
      monitor.log_silent_failure(context, nil, call_location:)
    end
  end

  def log_errors(errors)
    Rails.logger.error('Errors occurred while processing Intake Status batch', class: self.class.name, errors:)
  end
end
