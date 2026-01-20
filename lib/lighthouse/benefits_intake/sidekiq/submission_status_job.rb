# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'logging/monitor'

# Datadog Dashboard
# https://vagov.ddog-gov.com/dashboard/4d8-3fn-dbp/benefits-intake-form-submission-tracking
module BenefitsIntake
  # job for retrieving the status of submissions
  # @see lib/periodic_jobs.rb
  class SubmissionStatusJob
    include Sidekiq::Job

    sidekiq_options retry: false
    attr_reader :pending_attempts

    # tracking metric
    STATS_KEY = 'api.benefits_intake.submission_status'
    # number of days before a 'stale' submission
    STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
    # batch size for each request
    BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

    # Lighthouse `status` mapped to the `result` sent to the handler
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

      @pending_attempts = pending_submission_attempts(form_id)

      batch_process

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
      monitor.track_request(level, message, STATS_KEY, **payload)
    end

    # process a set of pending attempts
    #
    # list of pending attempts to process
    def batch_process
      return if pending_attempts.blank?

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

    # retrieve all pending attempts for the specified form_id
    #
    # @param form_type [String] the form ID to filter attempts by, or nil for all forms
    #
    # @return [Array<Lighthouse::SubmissionAttempt and/or FormSubmissionAttempt>] list of
    # pending attempts for the specified form
    def pending_submission_attempts(form_type)
      # filter running this job to the specific form_id
      form_ids = FORM_HANDLERS.keys.map(&:to_s)
      form_ids &= [form_type.to_s] if form_type
      attempts = []

      log(:info, "processing forms #{form_ids}")

      form_ids.each do |form_id|
        handler = FORM_HANDLERS[form_id]

        next unless handler.respond_to?(:pending_attempts)

        attempts += handler.pending_attempts
      end

      attempts
    end

    # mapping of benefits_intake_uuid to Lighthouse::SubmissionAttempt
    # improves lookup during processing
    def pending_attempts_hash
      @pah ||= pending_attempts.index_by(&:benefits_intake_uuid)
    end

    # respond to the status for each submission
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
      submission_attempt = pending_attempts_hash[uuid]
      if submission_attempt.is_a?(FormSubmissionAttempt)
        form_id = submission_attempt.form_submission.form_type
        saved_claim_id = submission_attempt.form_submission.saved_claim_id
      else
        form_id = submission_attempt.submission.form_id
        saved_claim_id = submission_attempt.submission.saved_claim_id
      end

      # double check for valid handler, should have been filtered in `perform`
      if (handler = FORM_HANDLERS[form_id])
        handler.new(saved_claim_id)&.update_attempt_record(status, submission, submission_attempt)
      end
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
      submission_attempt = pending_attempts_hash[uuid]
      if submission_attempt.is_a?(Lighthouse::SubmissionAttempt)
        submission = submission_attempt.submission
        form_id = submission.form_id
      else
        submission = submission_attempt.form_submission
        form_id = submission.form_type
      end

      queue_time = (Time.zone.now - submission_attempt.created_at).truncate
      result = STATUS_RESULT_MAP[status.to_sym] || 'pending'
      result = 'stale' if queue_time > STALE_SLA.days && result == 'pending'

      {
        form_id:,
        saved_claim_id: submission.saved_claim_id,
        uuid:,
        status:,
        result:,
        queue_time:,
        error_message: submission_attempt.error_message
      }
    end

    # @return [Logging::Monitor] the monitor used for tracking
    def monitor
      @monitor ||= Logging::Monitor.new('benefits_intake_submission_status_job')
    end

    # end class SubmissionStatusJob
  end

  # end module BenefitsIntake
end
