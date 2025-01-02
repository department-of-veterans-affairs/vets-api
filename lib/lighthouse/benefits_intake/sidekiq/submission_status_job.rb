# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'dependents/benefits_intake/submission_handler'
require 'pcpg/benefits_intake/submission_handler'
require 'vre/benefits_intake/submission_handler'

# Datadog Dashboard
# https://vagov.ddog-gov.com/dashboard/4d8-3fn-dbp/benefits-intake-form-submission-tracking
module BenefitsIntake
  class SubmissionStatusJob
    include Sidekiq::Job

    sidekiq_options retry: false

    STATS_KEY = 'api.benefits_intake.submission_status'
    STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
    BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

    # any status not listed will result in 'pending'
    STATUS_RESULT_MAP = {
      expired: 'failure',  # Indicates that documents were not successfully uploaded within the 15-minute window
      error: 'failure',    # Indicates that there was an error. Refer to the code and detail for further information
      vbms: 'success',     # Submission was successfully uploaded into a Veteran's eFolder within VBMS
      success: 'pending',  # Submission was successfully received into Lighthouse systems
      pending: 'pending',  # Submission is being processed
      stale: 'stale',      # Exceeds SLA (service level agreement) days for submission completion; non-lighthouse status
      received: 'received' # Submission (Burial) was received by VBMS
    }.freeze

    # A hash mapping form IDs to their corresponding handlers.
    # This constant is intentionally mutable.
    # @see register_handler
    FORM_HANDLERS = {} # rubocop:disable Style/MutableConstant

    # Registers a form class with a specific form ID.
    #
    # @param form_id [String] The form ID to register.
    # @param form_handler [Class] The class associated with the form ID.
    def self.register_handler(form_id, form_handler)
      FORM_HANDLERS[form_id] = form_handler
    end

    # Registers handlers for various form IDs.
    {
      '686C-674' => Dependents::BenefitsIntake::SubmissionHandler,
      '28-8832' => PCPG::BenefitsIntake::SubmissionHandler,
      '28-1900' => VRE::BenefitsIntake::SubmissionHandler
    }.each do |form_id, handler_class|
      register_handler(form_id, handler_class)
    end

    def initialize(batch_size: BATCH_SIZE)
      @batch_size = batch_size
    end

    def perform(form_id = nil)
      log(:info, 'started')

      pending_attempts = FormSubmissionAttempt.where(aasm_state: 'pending').includes(:form_submission)

      # filter running this job to a specific form_id/form_type
      pending_attempts.select! { |pa| pa.form_submission.form_type == form_id } if form_id

      batch_process(pending_attempts) unless pending_attempts.empty?

      log(:info, 'ended')
    end

    private

    attr_reader :batch_size, :form_id

    def log(level, msg, **payload)
      this = self.class.name
      message = format('%<class>s: %<msg>s', { class: this, msg: msg.to_s })
      Rails.logger.public_send(level, message, class: this, **payload)
    end

    def batch_process(pending_attempts)
      intake_service = BenefitsIntake::Service.new

      pending_attempts.each_slice(batch_size) do |batch|
        batch_uuids = batch.map(&:benefits_intake_uuid)
        log(:info, 'processing batch', batch_uuids:)

        response = intake_service.bulk_status(uuids: batch_uuids)

        log(:info, 'bulk status response', response:)
        raise response.body unless response.success?

        next unless (data = response.body['data'])

        handle_response(data)
      end
    rescue => e
      log(:error, 'ERROR processing batch', message: e.message)
    end

    def pending_attempts_hash
      @pah ||= FormSubmissionAttempt.where(aasm_state: 'pending').includes(:form_submission)
                                    .index_by(&:benefits_intake_uuid)
    end

    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    def handle_response(response_data)
      response_data.each do |submission|
        uuid = submission['id']

        next unless pending_attempts_hash[uuid]

        # Log the status for debugging
        status = submission.dig('attributes', 'status')
        log(:info, "Processing submission UUID: #{uuid}, Status: #{status}")

        update_attempt_record(uuid, status, submission)
        monitor_attempt_status(uuid, status)

        handle_attempt_result(uuid, status)
      end
    end

    def update_attempt_record(uuid, status, submission)
      form_submission_attempt = pending_attempts_hash[uuid]
      form_id = form_submission_attempt.form_submission.form_type
      saved_claim_id = form_submission_attempt.form_submission.saved_claim_id
      lighthouse_updated_at = submission.dig('attributes', 'updated_at')

      case status
      when 'expired'
        # Indicates that documents were not successfully uploaded within the 15-minute window.
        error_message = 'expired'
        form_submission_attempt.fail!

      when 'error'
        # Indicates that there was an error. Refer to the error code and detail for further information.
        error_message = "#{submission.dig('attributes', 'code')}: #{submission.dig('attributes', 'detail')}"
        form_submission_attempt.fail!

      when 'vbms'
        # Submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.vbms!
        monitor_success(form_id, saved_claim_id, uuid)
      end

      form_submission_attempt.update(lighthouse_updated_at:, error_message:)
    end

    def monitor_success(form_id, saved_claim_id, bi_uuid)
      # Remove this logic after SubmissionStatusJob replaces this one
      if form_id == '21P-530EZ' && Flipper.enabled?(:burial_received_email_notification)
        claim = SavedClaim::Burial.find_by(id: saved_claim_id)

        unless claim
          context = {
            form_id: form_id,
            claim_id: saved_claim_id,
            benefits_intake_uuid: bi_uuid
          }
          Burials::Monitor.new.log_silent_failure(context, nil, call_location: caller_locations.first)
          return
        end

        Burials::NotificationEmail.new(claim.id).deliver(:received)
      end
    end

    def monitor_attempt_status(uuid, status)
      form_submission_attempt, result = attempt_status_result(uuid, status)
      form_id = form_submission_attempt.form_submission.form_type

      metric = "#{STATS_KEY}.#{form_id}.#{result}"
      StatsD.increment(metric)
      StatsD.increment("#{STATS_KEY}.all_forms.#{result}")

      level = result == 'failure' ? :error : :info
      payload = {
        statsd: metric,
        form_id:,
        uuid:,
        result:,
        status:,
        time_to_transition: (Time.zone.now - form_submission_attempt.created_at).truncate,
        error_message: form_submission_attempt.error_message
      }
      log(level, "UUID: #{uuid}, status: #{status}, result: #{result}", **payload)
    end

    def handle_attempt_result(uuid, status)
      form_submission_attempt, result = attempt_status_result(uuid, status)
      saved_claim_id = form_submission_attempt.form_submission.saved_claim_id

      call_location = caller_locations.first
      context = { benefits_intake_uuid: uuid }
      FORM_HANDLERS[form_id]&.new(saved_claim_id)&.handle(result, call_location:, **context)
    rescue => e
      log(:error, 'ERROR handling result', message: e.message)
    end

    def attempt_status_result(uuid, status)
      form_submission_attempt = pending_attempts_hash[uuid]

      queue_time = (Time.zone.now - form_submission_attempt.created_at).truncate
      result = STATUS_RESULT_MAP[status.to_sym] || 'pending'
      result = 'stale' if queue_time > STALE_SLA.days && result == 'pending'

      [form_submission_attempt, result]
    end

    def send_burial_received_notification(form_id, saved_claim_id, bi_uuid)
      claim = SavedClaim::Burial.find_by(id: saved_claim_id)

      unless claim
        context = {
          form_id: form_id,
          claim_id: saved_claim_id,
          benefits_intake_uuid: bi_uuid
        }
        Burials::Monitor.new.log_silent_failure(context, nil, call_location: caller_locations.first)
        return
      end

      Burials::NotificationEmail.new(claim.id).deliver(:received)
    end

    # end class SubmissionStatusJob
  end

  # end module BenefitsIntake
end
