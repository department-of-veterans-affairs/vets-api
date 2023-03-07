# frozen_string_literal: true

module Form1010cg
  class Auditor
    attr_reader :logger

    STATSD_KEY_PREFIX   = 'api.form1010cg'
    LOGGER_PREFIX       = 'Form 10-10CG'
    LOGGER_FILTER_KEYS  = [:veteran_name].freeze

    METRICS = lambda do
      submission_prefix = "#{STATSD_KEY_PREFIX}.submission"

      OpenStruct.new(
        submission: OpenStruct.new(
          attempt: "#{submission_prefix}.attempt",
          success: "#{submission_prefix}.success",
          caregivers: OpenStruct.new(
            primary_no_secondary: "#{submission_prefix}.caregivers.primary_no_secondary",
            primary_one_secondary: "#{submission_prefix}.caregivers.primary_one_secondary",
            primary_two_secondary: "#{submission_prefix}.caregivers.primary_two_secondary",
            no_primary_one_secondary: "#{submission_prefix}.caregivers.no_primary_one_secondary",
            no_primary_two_secondary: "#{submission_prefix}.caregivers.no_primary_two_secondary"
          ),
          failure: OpenStruct.new(
            client: OpenStruct.new(
              data: "#{submission_prefix}.failure.client.data",
              qualification: "#{submission_prefix}.failure.client.qualification"
            ),
            attachments: "#{submission_prefix}.failure.attachments"
          )
        ),
        pdf_download: "#{STATSD_KEY_PREFIX}.pdf_download"
      )
    end.call

    def self.metrics
      METRICS
    end

    def initialize(logger = Rails.logger)
      @logger = logger
    end

    def record(event, **context)
      message = "record_#{event}"
      context.any? ? send(message, **context) : send(message)
    end

    def record_submission_attempt
      increment self.class.metrics.submission.attempt
    end

    def record_submission_success(claim_guid:, carma_case_id:, metadata:, attachments:, attachments_job_id:)
      increment self.class.metrics.submission.success
      log(
        'Submission Successful',
        claim_guid: claim_guid,
        carma_case_id: carma_case_id,
        metadata: metadata,
        attachments: attachments,
        attachments_job_id: attachments_job_id
      )
    end

    # rubocop:disable Metrics/MethodLength
    def record_caregivers(claim)
      secondaries_count = 0
      %w[one two].each do |attr|
        secondaries_count += 1 if claim.public_send("secondary_caregiver_#{attr}_data").present?
      end

      if claim.primary_caregiver_data.present?
        case secondaries_count
        when 0
          increment(self.class.metrics.submission.caregivers.primary_no_secondary)
        when 1
          increment(self.class.metrics.submission.caregivers.primary_one_secondary)
        when 2
          increment(self.class.metrics.submission.caregivers.primary_two_secondary)
        end
      else
        case secondaries_count
        when 1
          increment(self.class.metrics.submission.caregivers.no_primary_one_secondary)
        when 2
          increment(self.class.metrics.submission.caregivers.no_primary_two_secondary)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def record_submission_failure_client_data(errors:, claim_guid: nil)
      increment self.class.metrics.submission.failure.client.data
      log 'Submission Failed: invalid data provided by client', claim_guid: claim_guid, errors: errors
    end

    def record_submission_failure_client_qualification(claim_guid:)
      increment self.class.metrics.submission.failure.client.qualification
      log 'Submission Failed: qualifications not met', claim_guid: claim_guid
    end

    def record_pdf_download
      increment self.class.metrics.pdf_download
    end

    def record_attachments_delivered(claim_guid:, carma_case_id:, attachments:)
      log(
        'Attachments Delivered',
        claim_guid: claim_guid,
        carma_case_id: carma_case_id,
        attachments: attachments
      )
    end

    def log_mpi_search_result(claim_guid:, form_subject:, result:)
      labels = { found: 'found', not_found: 'NOT FOUND', skipped: 'search was skipped' }
      result_label = labels[result]
      log("MPI Profile #{result_label} for #{form_subject.titleize}", { claim_guid: claim_guid })
    end

    private

    def increment(stat)
      StatsD.increment stat
    end

    def log(message, context_hash = {})
      logger.send(:info, "[#{LOGGER_PREFIX}] #{message}", **deep_apply_filter(context_hash))
    end

    def deep_apply_filter(value)
      case value
      when Array
        value.map { |v| deep_apply_filter(v) }
      when Hash
        value.each_with_object({}) do |(key, v), result|
          result[key] = if LOGGER_FILTER_KEYS.include?(key.to_s) || LOGGER_FILTER_KEYS.include?(key.to_sym)
                          ActiveSupport::ParameterFilter::FILTERED
                        else
                          deep_apply_filter(v)
                        end
        end
      else
        value
      end
    end
  end
end
