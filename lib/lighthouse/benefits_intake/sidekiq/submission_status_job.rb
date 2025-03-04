# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

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
      expired: 'failure', # Indicates that documents were not successfully uploaded within the 15-minute window
      error: 'failure',   # Indicates that there was an error. Refer to the code and detail for further information
      vbms: 'success',    # Submission was successfully uploaded into a Veteran's eFolder within VBMS
      success: 'pending', # Submission was successfully received into Lighthouse systems
      pending: 'pending', # Submission is being processed
      stale: 'stale'      # Exceeds SLA (service level agreement) days for submission completion; non-lighthouse status
    }.freeze

    # A hash mapping form IDs to their corresponding handlers.
    # This constant is intentionally mutable.
    # @see register_handler
    FORM_HANDLERS = {} # rubocop:disable Style/MutableConstant

    # Registers a form class with a specific form ID.
    # @see config/initializers/benefits_intake_submission_status_handlers.rb
    #
    # @param form_id [String] The form ID to register.
    # @param form_handler [Class] The class associated with the form ID.
    def self.register_handler(form_id, form_handler)
      FORM_HANDLERS[form_id] = form_handler
    end

    # constructor
    #
    # @param batch_size [Integer] the number of records to process in a single request
    def initialize(batch_size: BATCH_SIZE)
      @batch_size = batch_size
    end

    # execute the bulk status query to lighthouse
    #
    # @param form_id [String] process only form submission attempts of this form type
    def perform(form_id = nil)
      return unless Flipper.enabled?(:benefits_intake_submission_status_job)

      log(:info, 'started')

      pending_attempts = FormSubmissionAttempt.where(aasm_state: 'pending').includes(:form_submission).to_a

      # filter running this job to the specific form_id
      form_ids = FORM_HANDLERS.keys.map(&:to_s)
      form_ids &= [form_id.to_s] if form_id
      log(:info, "processing forms #{form_ids}")

      pending_attempts.select! { |pa| form_ids.include?(pa.form_submission.form_type) }

      batch_process(pending_attempts) unless pending_attempts.empty?

      log(:info, 'ended')
    rescue => e
      # catch and log, but not re-raise to avoid sidekiq exhaustion alerts
      log(:error, 'ERROR', message: e.message)
    end

    private

    attr_reader :batch_size

    # utility function, @see Rails.logger
    #
    # @param level [Symbol|String] the logger function to call
    # @param msg [String] the message to be logged
    # @param payload [Hash] additional parameters to pass to log
    def log(level, msg, **payload)
      this = self.class.name
      message = format('%<class>s: %<msg>s', { class: this, msg: msg.to_s })
      Rails.logger.public_send(level, message, class: this, **payload)
    end

    # process a set of pending attempts
    #
    # @param pending_attempts [Array<FormSubmissionAttempt>] list of pending attempts to process
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
    end

    # mapping of benefits_intake_uuid to FormSubmissionAttempt
    # improves lookup during processing
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
        log(:info, "Processing submission UUID: #{uuid}, Status: #{status}", submission:)

        update_attempt_record(uuid, status, submission)
        monitor_attempt_status(uuid, status)

        handle_attempt_result(uuid, status)
      end
    end

    # perform aasm_state change on the attempt based on returned status
    #
    # @param uuid [UUID] the benefits_intake_uuid being processed
    # @param status [String] the returned status
    # @param submission [Hash] the full data hash returned for this record
    def update_attempt_record(uuid, status, submission)
      form_submission_attempt = pending_attempts_hash[uuid]
      form_submission_attempt.update(lighthouse_updated_at: submission.dig('attributes', 'updated_at'))

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
      end

      form_submission_attempt.update(error_message:)
    end

    # monitoring of the submission attempt status
    #
    # @param uuid [UUID] the benefits_intake_uuid being processed
    # @param status [String] the returned status
    def monitor_attempt_status(uuid, status)
      context = attempt_status_result_context(uuid, status)
      result = context[:result]

      metric = "#{STATS_KEY}.#{context[:form_id]}.#{result}"
      StatsD.increment(metric)
      StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
      context[:statsd] = metric

      level = result == 'failure' ? :error : :info
      log(level, "UUID: #{uuid}, status: #{status}, result: #{result}", **context)
    end

    # call handler function to further process a submission status
    #
    # @param uuid [UUID] the benefits_intake_uuid being processed
    # @param status [String] the returned status
    def handle_attempt_result(uuid, status)
      context = attempt_status_result_context(uuid, status)

      # double check for valid handler, should have been filtered in `perform`
      if (handler = FORM_HANDLERS[context[:form_id]])
        call_location = caller_locations.first
        handler.new(context[:saved_claim_id])&.handle(context[:result], call_location:, **context)
      end
    rescue => e
      log(:error, 'ERROR handling result', message: e.message, **context)
    end

    # utility function to retrieve submission transformed submission data
    # - map status to the recorded result in the database
    #
    # @param uuid [UUID] the benefits_intake_uuid being processed
    # @param status [String] the returned status
    #
    # @return [Hash] context of attempt result, payload suited for logging and handlers
    def attempt_status_result_context(uuid, status)
      form_submission_attempt = pending_attempts_hash[uuid]

      queue_time = (Time.zone.now - form_submission_attempt.created_at).truncate
      result = STATUS_RESULT_MAP[status.to_sym] || 'pending'
      result = 'stale' if queue_time > STALE_SLA.days && result == 'pending'

      {
        form_id: form_submission_attempt.form_submission.form_type,
        saved_claim_id: form_submission_attempt.form_submission.saved_claim_id,
        uuid:,
        status:,
        result:,
        queue_time:,
        error_message: form_submission_attempt.error_message
      }
    end

    # end class SubmissionStatusJob
  end

  # end module BenefitsIntake
end
