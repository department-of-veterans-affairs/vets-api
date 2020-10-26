# frozen_string_literal: true

module Form1010cg
  class Auditor
    include Singleton

    STATSD_KEY_PREFIX = 'api.form1010cg'
    LOGGER_PREFIX     = 'Form 10-10CG'

    def self.metrics
      submission_prefix = STATSD_KEY_PREFIX + '.submission'
      OpenStruct.new(
        submission: OpenStruct.new(
          attempt: submission_prefix + '.attempt',
          success: submission_prefix + '.success',
          failure: OpenStruct.new(
            client: OpenStruct.new(
              data: submission_prefix + '.failure.client.data',
              qualification: submission_prefix + '.failure.client.qualification'
            )
          )
        ),
        pdf_download: STATSD_KEY_PREFIX + '.pdf_download'
      )
    end

    def record(event, **context)
      message = "record_#{event}"
      context.any? ? send(message, context) : send(message)
    end

    def record_submission_attempt
      increment self.class.metrics.submission.attempt
    end

    def record_submission_success(claim_guid:, carma_case_id:, metadata:, attachments:)
      increment self.class.metrics.submission.success
      log(
        'Submission Successful',
        claim_guid: claim_guid,
        carma_case_id: carma_case_id,
        metadata: metadata,
        attachments: attachments
      )
    end

    def record_submission_failure_client_data(errors:, claim_guid: nil)
      increment self.class.metrics.submission.failure.client.data
      log 'Submission Failed: invalid data provided by client', claim_guid: claim_guid, errors: errors
    end

    def record_submission_failure_client_qualification(claim_guid:, veteran_name:)
      increment self.class.metrics.submission.failure.client.qualification
      log 'Submission Failed: qualifications not met', claim_guid: claim_guid, veteran_name: veteran_name
    end

    def record_pdf_download
      increment self.class.metrics.pdf_download
    end

    def log_mpi_search_result(claim_guid:, form_subject:, result:)
      result_label = case result
                     when :found
                       'found'
                     when :not_found
                       'NOT FOUND'
                     when :skipped
                       'search was skipped'
                     end

      log "MPI Profile #{result_label} for #{form_subject.titleize}", claim_guid: claim_guid
    end

    private

    def increment(stat)
      StatsD.increment stat
    end

    def log(message, data_hash = {})
      Rails.logger.send :info, "[#{LOGGER_PREFIX}] #{message}", data_hash
    end
  end
end
