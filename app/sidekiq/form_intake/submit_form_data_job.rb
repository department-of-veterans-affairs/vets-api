# frozen_string_literal: true

require 'vets/shared_logging'

module FormIntake
  # Sidekiq job to submit form data to GCIO digitization API
  # Retries with exponential backoff for ~2 days
  class SubmitFormDataJob
    include Sidekiq::Job
    include Vets::SharedLogging

    # retry for 2d 1h 47m 12s (matches Lighthouse pattern)
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16, queue: 'low'

    # Non-retryable HTTP status codes (fail immediately)
    NON_RETRYABLE_ERRORS = [400, 401, 403, 404, 422].freeze

    # Metrics prefix includes "mms" to clarify this submits to GCIO/IBM MMS
    STATSD_KEY_PREFIX = 'worker.form_intake_mms.submit_form_data'

    sidekiq_retries_exhausted do |msg, _ex|
      form_submission_id = msg['args'].first
      handle_exhaustion(form_submission_id, msg['error_message'])
    end

    # rubocop:disable Metrics/MethodLength
    def perform(form_submission_id, benefits_intake_uuid)
      @form_submission = FormSubmission.find(form_submission_id)
      @benefits_intake_uuid = benefits_intake_uuid

      # Log job start
      Rails.logger.info('FormIntake::SubmitFormDataJob started', {
                          form_submission_id:,
                          form_type: @form_submission.form_type,
                          benefits_intake_uuid:
                        })

      # Validate form is still eligible
      unless eligible_for_submission?
        log_and_skip('Form not eligible')
        return
      end

      # Get mapper for form type
      mapper = get_mapper
      unless mapper
        log_and_skip('No mapper found')
        return
      end

      # Execute submission with tracing
      Datadog::Tracing.trace('form_intake.submit_form_data_job') do |span|
        add_trace_tags(span)
        execute_submission(mapper)
      end
    rescue FormIntake::ServiceError => e
      handle_service_error(e)
    rescue ActiveRecord::RecordNotFound => e
      # Form submission was deleted, don't retry
      Rails.logger.warn('Form submission deleted during job execution', {
                          form_submission_id:,
                          benefits_intake_uuid:,
                          error: e.message
                        })
    rescue => e
      handle_unexpected_error(e)
      log_exception_to_sentry(e, {
                                form_submission_id: @form_submission&.id,
                                form_type: @form_submission&.form_type,
                                benefits_intake_uuid: @benefits_intake_uuid
                              })
    end
    # rubocop:enable Metrics/MethodLength

    private

    def eligible_for_submission?
      FormIntake.enabled_for_form?(@form_submission.form_type, @form_submission.user_account)
    end

    def get_mapper
      mapper_class = FormIntake::Mappers::Registry.mapper_for(@form_submission.form_type)
      mapper_class.new(@form_submission, @benefits_intake_uuid)
    rescue FormIntake::Mappers::MappingNotFoundError => e
      Rails.logger.error('Mapper not found', error: e.message, form_type: @form_submission.form_type)
      nil
    end

    def execute_submission(mapper)
      # Find or create tracking record
      @form_intake_submission = find_or_create_submission

      # Increment retry count if retrying (uses in-memory value, no extra query)
      @form_intake_submission.increment_retry_count! if @form_intake_submission.retry_count.positive?

      # Build payload using form-specific mapper
      payload = mapper.to_gcio_payload

      # Submit to GCIO API
      service = FormIntake::Service.new
      response = service.submit_form_data(payload, @benefits_intake_uuid)

      # Success! Update tracking record
      handle_success(response, payload)
    end

    def find_or_create_submission
      FormIntakeSubmission.find_or_create_by!(
        form_submission: @form_submission,
        benefits_intake_uuid: @benefits_intake_uuid
      ) do |submission|
        submission.aasm_state = 'pending'
      end
    end

    def handle_success(response, payload)
      # NOTE: request_payload and response are encrypted at rest via Lockbox
      # See app/models/form_intake_submission.rb for encryption configuration
      @form_intake_submission.update!(
        form_intake_submission_id: response[:submission_id],
        gcio_tracking_number: response[:tracking_number],
        request_payload: payload.to_json,
        response: response[:body]
      )

      @form_intake_submission.submit!
      @form_intake_submission.succeed!

      Rails.logger.info(
        'GCIO submission succeeded',
        form_submission_id: @form_submission.id,
        form_intake_submission_id: @form_intake_submission.id,
        gcio_submission_id: response[:submission_id],
        retry_count: @form_intake_submission.retry_count,
        benefits_intake_uuid: @benefits_intake_uuid
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.success", tags:)
    end

    # rubocop:disable Metrics/MethodLength
    def handle_service_error(error)
      status_code = error.status_code # Extract to avoid duplicate method calls
      error_message = error.message

      # NOTE: error_message is encrypted at rest via Lockbox
      # Truncate to 10,000 chars to prevent DB overflow
      @form_intake_submission.update!(
        error_message: error_message.to_s.truncate(10_000),
        last_attempted_at: Time.current
      )

      if NON_RETRYABLE_ERRORS.include?(status_code)
        @form_intake_submission.fail!

        Rails.logger.error(
          'GCIO submission non-retryable error',
          form_submission_id: @form_submission.id,
          form_intake_submission_id: @form_intake_submission.id,
          error: error_message,
          status_code:,
          benefits_intake_uuid: @benefits_intake_uuid
        )

        # Log non-retryable errors to Sentry for visibility
        log_exception_to_sentry(error, {
                                  form_submission_id: @form_submission.id,
                                  form_type: @form_submission.form_type,
                                  status_code:
                                })

        StatsD.increment("#{STATSD_KEY_PREFIX}.non_retryable_error",
                         tags: tags + ["status:#{status_code}"])

        return # Don't re-raise, prevents retry
      end

      # Retryable error - log as warning (will be retried by Sidekiq)
      Rails.logger.warn(
        'GCIO submission retryable error - will retry',
        form_submission_id: @form_submission.id,
        form_intake_submission_id: @form_intake_submission.id,
        error: error_message,
        status_code:,
        retry_count: @form_intake_submission.retry_count,
        max_retries: 16,
        benefits_intake_uuid: @benefits_intake_uuid
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.retryable_error",
                       tags: tags + ["status:#{status_code}"])

      raise # Re-raise to trigger Sidekiq retry
    end
    # rubocop:enable Metrics/MethodLength

    def handle_unexpected_error(error)
      Rails.logger.error(
        'GCIO submission unexpected error',
        form_submission_id: @form_submission.id,
        form_intake_submission_id: @form_intake_submission&.id,
        error_class: error.class.name,
        error: error.message,
        benefits_intake_uuid: @benefits_intake_uuid
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.unexpected_error",
                       tags: tags + ["error_class:#{error.class.name}"])

      raise # Re-raise to trigger Sidekiq retry
    end

    def log_and_skip(reason)
      Rails.logger.info(
        "GCIO submission skipped: #{reason}",
        form_submission_id: @form_submission.id,
        form_type: @form_submission.form_type,
        benefits_intake_uuid: @benefits_intake_uuid
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.skipped",
                       tags: tags + ["reason:#{reason.parameterize.underscore}"])
    end

    def add_trace_tags(span)
      span.set_tag('form_submission_id', @form_submission.id)
      span.set_tag('form_type', @form_submission.form_type)
      span.set_tag('benefits_intake_uuid', @benefits_intake_uuid)
      span.set_tag('retry_count', @form_intake_submission&.retry_count || 0)
    end

    def tags
      [
        "form_type:#{@form_submission.form_type}",
        "benefits_intake_uuid:#{@benefits_intake_uuid}"
      ]
    end

    class << self
      # rubocop:disable Metrics/MethodLength
      def handle_exhaustion(form_submission_id, error_message)
        form_intake_submission = FormIntakeSubmission.find_by(form_submission_id:)
        return unless form_intake_submission

        form_intake_submission.fail!

        Rails.logger.error(
          'GCIO submission retries exhausted',
          form_submission_id:,
          form_intake_submission_id: form_intake_submission.id,
          error: error_message,
          retry_count: form_intake_submission.retry_count
        )

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        # Track as silent failure if no other notification mechanism exists
        StatsD.increment('silent_failure', tags: [
                           'service:form-intake',
                           'function:gcio_api_submission'
                         ])
      rescue => e
        # Ensure exhaustion callback doesn't raise - log but don't fail
        Rails.logger.error(
          'Error in FormIntake::SubmitFormDataJob exhaustion handler',
          form_submission_id:,
          error: e.message,
          backtrace: e.backtrace&.first(5)
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
