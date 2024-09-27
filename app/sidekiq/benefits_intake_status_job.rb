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

  def initialize(batch_size: BATCH_SIZE, intake_service: BenefitsIntake::Service.new, logger: Rails.logger)
    @batch_size = batch_size
    @intake_service = intake_service
    @logger = logger
  end

  def perform
    @logger.info('BenefitsIntakeStatusJob started')

    pending_form_submissions = load_pending_submissions
    # We're calculating the resolved_form_submissions and removing them because it is possible for a FormSubmission
    # to have two (or more) attempts, one 'pending' and the other 'vbms'. In such cases we don't want to include
    # that FormSubmission because it has been resolved.
    total_handled, result = batch_process(pending_form_submissions)

    @logger.info("BenefitsIntakeStatusJob ended. Total handled: #{total_handled}") if result
  end

  private

  def load_pending_submissions
    form_submissions_and_attempts = FormSubmission.joins(:form_submission_attempts)
    resolved_form_submission_ids = form_submissions_and_attempts
                                   .where(form_submission_attempts: { aasm_state: %w[vbms failure] })
                                   .pluck(:id)

    form_submissions_and_attempts
      .select(:id, :benefits_intake_uuid, :form_type)
      .where(form_submission_attempts: { aasm_state: 'pending' })
      .where.not(id: resolved_form_submission_ids)
  end

  def batch_process(pending_form_submissions)
    total_handled = 0

    pending_form_submissions.each_slice(@batch_size) do |batch|
      total_handled += process_batch(batch)
    end

    [total_handled, true]
  rescue => e
    log_error(e, 'Error processing Intake Status batch')
    [total_handled, false]
  end

  def process_batch(batch)
    total_handled = 0
    batch_uuids = batch.map(&:benefits_intake_uuid)

    response = @intake_service.bulk_status(uuids: batch_uuids)

    # Log the entire response to check for anomalies
    @logger.info("Received bulk status response: #{response.body}")

    if response.success?
      total_handled += handle_response(response, batch)
    else
      @logger.error("Error in bulk status response: #{response.body}")
      raise response.body
    end

    total_handled
  end

  def handle_response(response, pending_form_submissions)
    submissions_by_uuid = pending_form_submissions.index_by(&:benefits_intake_uuid)

    # Ensure we log the response data for further debugging
    if response.body['data'].blank?
      @logger.error("Response data is blank or missing: #{response.body}")
      return 0
    end

    response.body['data'].sum do |submission|
      @logger.info("Processing submission: #{submission.inspect}")
      handle_submission(submission, submissions_by_uuid[submission['id']])
    end
  end

  def handle_submission(submission, form_submission)
    return 0 unless form_submission

    # https://developer.va.gov/explore/api/benefits-intake/docs
    status = submission.dig('attributes', 'status')

    @logger.info("Retrieved status: #{status} for UUID: #{form_submission.benefits_intake_uuid}")

    lighthouse_updated_at = submission.dig('attributes', 'updated_at')
    attempt = form_submission.latest_pending_attempt
    time_to_transition = (Time.zone.now - attempt.created_at).to_i

    @logger.info("Time to transition: #{time_to_transition} seconds for UUID: #{form_submission.benefits_intake_uuid}")

    case status
    when 'expired'
      # Expired - Indicate that documents were not successfully uploaded within the 15-minute window.
      handle_expired_status(attempt, form_submission, lighthouse_updated_at, time_to_transition)
    when 'error'
      # Error - Indicates that there was an error. Refer to the error code and detail for further information.
      handle_error_status(attempt, form_submission, submission, lighthouse_updated_at, time_to_transition)
    when 'vbms'
      # submission was successfully uploaded into a Veteran's eFolder within VBMS
      handle_vbms_status(attempt, form_submission, lighthouse_updated_at, time_to_transition)
    else
      # exceeds SLA (service level agreement) days for submission completion
      handle_stale_pending_status(form_submission, time_to_transition)
      @logger.info("Handling as pending: #{form_submission.benefits_intake_uuid}, status: #{status}")
    end

    1
  end

  def handle_expired_status(attempt, sub, lighthouse_updated_at, time_to_transition)
    update_attempt_status(attempt, 'expired', lighthouse_updated_at)
    attempt.fail!
    log_result('failure', sub.form_type, sub.benefits_intake_uuid, time_to_transition, 'expired')
  end

  def handle_error_status(attempt, sub, submission, lighthouse_updated_at, time_to_transition)
    error_message = "#{submission.dig('attributes', 'code')}: #{submission.dig('attributes', 'detail')}"
    update_attempt_status(attempt, error_message, lighthouse_updated_at)
    attempt.fail!
    log_result('failure', sub.form_type, sub.benefits_intake_uuid, time_to_transition, error_message)
  end

  def handle_vbms_status(attempt, sub, lighthouse_updated_at, time_to_transition)
    update_attempt_status(attempt, nil, lighthouse_updated_at)
    attempt.vbms!
    log_result('success', sub.form_type, sub.benefits_intake_uuid, time_to_transition)
  end

  def handle_stale_pending_status(sub, time_to_transition)
    if time_to_transition > STALE_SLA.days
      log_result('stale', sub.form_type, sub.benefits_intake_uuid, time_to_transition)
    end
  end

  def update_attempt_status(attempt, error_message, lighthouse_updated_at)
    update_params = { lighthouse_updated_at: }
    update_params[:error_message] = error_message if error_message.present?
    attempt.update(update_params)
  end

  def log_result(result, form_id, uuid, time_to_transition = nil, error_message = nil)
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")

    log_method = result == 'failure' ? :error : :info
    @logger.public_send(
      log_method,
      'BenefitsIntakeStatusJob',
      result:, form_id:, uuid:, time_to_transition:, error_message:
    )
  end

  def log_error(exception, message)
    @logger.error(message, class: self.class.name, error: exception.message, backtrace: exception.backtrace)
  end
end
