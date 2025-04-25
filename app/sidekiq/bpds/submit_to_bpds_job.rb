# frozen_string_literal: true

require 'bpds/service'
require 'bpds/monitor'

module BPDS
  class SubmitToBPDSJob
    include Sidekiq::Job
    sidekiq_options retry: 16, queue: 'low'
    sidekiq_retries_exhausted do |msg, error|
      ::Rails.logger.error("SubmitToBPDSJob exhausted all retries for BPDS Submission ID: #{msg['args'][0]}")
      bpds_submission = BPDS::Submission.find_by(id: msg['args'][0])
      bpds_submission&.submission_attempts&.create(status: 'failure', error_message: error&.message)
    end

    def perform(bpds_submission_id)
      init(bpds_submission_id)

      begin
        # Submit the BPDS submission to the BPDS service
        response = BPDS::Service.new.submit_json(@bpds_submission.saved_claim)
        @bpds_submission_attempt.update(status: 'submitted', response: response.to_json, bpds_id: response['uuid'])
        @monitor.track_submit_success(@bpds_submission.saved_claim_id)
      rescue => e
        @bpds_submission_attempt.update(status: 'failure', error_message: e.message)
        @monitor.track_submit_failure(@bpds_submission.saved_claim_id, e)
        raise
      end
    end

    private

    def init(bpds_submission_id)
      @bpds_submission = BPDS::Submission.find_by(id: bpds_submission_id)
      @bpds_submission_attempt = @bpds_submission.submission_attempts.create
      @monitor = BPDS::Monitor.new
      @monitor.track_submit_begun(@bpds_submission.id)
    end
  end
end
