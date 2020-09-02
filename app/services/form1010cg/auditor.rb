# frozen_string_literal: true

module Form1010cg
  class Auditor
    LOGGER_PREFIX     = 'Form 10-10CG'
    STATSD_KEY_PREFIX = 'api.form1010cg'

    # EVENTS = [
    #   :submission_attempt,
    #   :submission_success,
    #   :submission_failure_client_data,
    #   :submission_failure_client_qualification,
    #   :pdf_download
    #   # :carma_attachment_delivered(10-10CG)
    #   # :carma_attachment_dropped(10-10CG)
    #   # :carma_attachment_delivered(POA)
    #   # :carma_attachment_dropped(POA)
    # ]

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

    def initialize(user_api_cookie:, user_ga_cid:)
      # TODO: user Rails.logger
      @logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
      @user_api_cookie = user_api_cookie
      @user_ga_cid = user_ga_cid
    end

    def record(event, **args)
      send("record_#{event}", **args)
    end

    def record_submission_attempt(_data)
      increment self.class.metrics.submission.attempt
      log :info, 'Submission Attempt'
    end

    def record_submission_success(claim_guid:, carma_case_id:)
      increment self.class.metrics.submission.success
      log :info, 'Submission Success', claim_guid: claim_guid, carma_case_id: carma_case_id
    end

    def record_submission_failure_client_data(claim_guid:)
      increment self.class.metrics.failure.client.data
      # TODO: add the exeption for additional context
      log :info, 'Submission Failure - Client - Data', claim_guid: claim_guid
    end

    def record_submission_failure_client_qualification(claim_guid:)
      increment self.class.metrics.failure.client.qualification
      # TODO: add the exeption for additional context
      log :info, 'Submission Failure - Client - Qualification', claim_guid: claim_guid
    end

    def record_user_pdf_download(_data)
      increment self.class.metrics.pdf_download
      log :info, 'PDF Download'
    end

    private

    def increment(stat)
      StatsD.increment stat
    end

    def log(log_level, message, data_hash = {})
      @logger.tagged(LOGGER_PREFIX) do |logger|
        paramaters  = logify_hash(user_data.merge(data_hash))
        output      = [message, paramaters].join(' ')

        logger.send log_level, output
      end
    end

    def user_data
      { user_api_cookie: @user_api_cookie, user_ga_cid: @user_ga_cid }
    end

    def logify_hash(data = {})
      data.map { |key, value| "#{key}=#{value}" }.join(' ')
    end
  end
end
