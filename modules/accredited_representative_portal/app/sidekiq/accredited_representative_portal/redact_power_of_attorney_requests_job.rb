# frozen_string_literal: true

require 'sidekiq'

module AccreditedRepresentativePortal
  # Job to redact PII from PowerOfAttorneyRequests that meet specific criteria
  # (stale resolved or expired). Redaction involves removing the associated
  # form and submission, and nullifying the resolution reason.
  class RedactPowerOfAttorneyRequestsJob
    include Sidekiq::Job
    sidekiq_options retry: 3

    STALE_RESOLUTION_DURATION = 60.days

    def perform
      log_start
      to_redact = eligible_requests_for_redaction
      results = process_requests(to_redact)
      log_end(results)
    end

    private

    def eligible_requests_for_redaction
      combined_ids = (expired_request_ids + stale_processed_request_ids).uniq

      PowerOfAttorneyRequest
        .where(id: combined_ids)
        .includes(:resolution, :power_of_attorney_form, :power_of_attorney_form_submission)
    end

    def expired_request_ids
      resolution_table_name = PowerOfAttorneyRequestResolution.table_name

      PowerOfAttorneyRequest
        .joins(:resolution)
        .unredacted
        .where(resolution_table_name => {
                 resolving_type: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration'
               }).ids
    end

    def stale_processed_request_ids
      threshold = Time.current - STALE_RESOLUTION_DURATION
      resolution_table_alias = 'resolution' # The alias defined in processed_join_sql

      PowerOfAttorneyRequest
        .processed
        .unredacted
        .where("#{resolution_table_alias}.created_at < ?", threshold)
        .where.not(
          "#{resolution_table_alias}.resolving_type = ?",
          'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration'
        ).ids
    end

    def process_requests(requests_to_process)
      results = { redacted: 0, errors: 0 }

      requests_to_process.each do |request|
        if attempt_redaction(request)
          results[:redacted] += 1
        else
          results[:errors] += 1
        end
      end

      results
    end

    # Attempts to redact a single request, handling potential errors
    # Returns true on success, false on failure
    def attempt_redaction(request)
      redact_request(request)
      true
    rescue => e
      log_redaction_error(request, e)
      false
    end

    # Performs the actual redaction logic for a single request within a transaction
    def redact_request(request)
      request.transaction do
        log_request_redaction(request)

        form = request.power_of_attorney_form
        submission = request.power_of_attorney_form_submission
        resolution = request.resolution

        form&.destroy! # Delete form

        # Redact submission data
        if submission.present?
          submission.update!(
            service_response_ciphertext: nil,
            error_message_ciphertext: nil,
            encrypted_kms_key: nil
          )
        end

        # Nullify reason on the resolution if it exists and takes a reason
        resolution&.update!(reason: nil) if resolution&.resolving&.accepts_reasons?

        # Mark request as redacted
        request.redacted_at = Time.current

        # Skip validations to allow required fields to pass after redacting
        request.save(validate: false)
      end
    end

    def log_start
      Rails.logger.info(
        "#{self.class.name}: Starting job."
      )
    end

    def log_request_redaction(request)
      Rails.logger.info(
        "#{self.class.name}: Redacting PowerOfAttorneyRequest ##{request.id}"
      )
    end

    def log_redaction_error(request, error)
      Rails.logger.error(
        "#{self.class.name}: Failed to redact PowerOfAttorneyRequest ##{request.id}. " \
        "Error: #{error.message}\n#{error.backtrace.join("\n")}"
      )
    end

    def log_end(results)
      Rails.logger.info(
        "#{self.class.name}: Finished job. Redacted #{results[:redacted]} requests. " \
        "Encountered #{results[:errors]} errors."
      )
    end
  end
end
