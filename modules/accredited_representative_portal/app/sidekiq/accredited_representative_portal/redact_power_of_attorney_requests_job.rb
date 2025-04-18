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
      or_conditions_sql = <<~SQL.squish
        (ar_power_of_attorney_form_submissions.service_response_ciphertext IS NOT NULL OR
         ar_power_of_attorney_form_submissions.error_message_ciphertext IS NOT NULL OR
         resolution.reason_ciphertext IS NOT NULL)
      SQL

      base_query = PowerOfAttorneyRequest
                   .joins(
                     :resolution,
                     :power_of_attorney_form,
                     :power_of_attorney_form_submission
                   )
                   .where(redacted_at: nil)
                   .where(resolution: {
                            resolving_type: PowerOfAttorneyRequestExpiration.name
                          })

      final_query = base_query.where(or_conditions_sql)
      final_query.distinct.ids
    end

    def stale_processed_request_ids
      threshold = Time.current - STALE_RESOLUTION_DURATION
      resolution_alias = 'resolution'
      submission_alias = 'succeeded_form_submission'

      or_conditions_sql = <<~SQL.squish
        (#{submission_alias}.service_response_ciphertext IS NOT NULL OR
         #{submission_alias}.error_message_ciphertext IS NOT NULL OR
         #{resolution_alias}.reason_ciphertext IS NOT NULL)
      SQL

      query = PowerOfAttorneyRequest
              .processed
              .where(redacted_at: nil)
              .where("#{resolution_alias}.created_at < ?", threshold)
              .where.not(
                "#{resolution_alias}.resolving_type = ?", PowerOfAttorneyRequestExpiration.name
              ).where(or_conditions_sql)

      query.distinct.ids
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

        # 1. Delete associated form
        form&.delete

        # 2. Redact submission data using update_columns direct to the db
        # we're using #update_columns to skip validation because the redaction
        # removes required fields and will leave the record invalid
        # rubocop:disable Rails/SkipsModelValidations
        if submission.present?
          submission.update_columns(
            # Use the actual ciphertext/key column names
            service_response_ciphertext: nil,
            error_message_ciphertext: nil
          )
        end

        # 3. Redact resolution data using update_columns
        resolution.update_columns(reason_ciphertext: nil) if resolution.present?

        # 4. Mark request as redacted
        # update_column is fine here as it's just one field
        request.update_column(:redacted_at, Time.current)
        # rubocop:enable Rails/SkipsModelValidations
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
