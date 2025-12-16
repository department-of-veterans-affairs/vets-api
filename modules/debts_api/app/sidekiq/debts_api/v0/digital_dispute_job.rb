# frozen_string_literal: true

require 'debts_api/v0/digital_dispute_dmc_service'

module DebtsApi
  class V0::DigitalDisputeJob
    include Sidekiq::Worker

    sidekiq_retries_exhausted do |job, ex|
      StatsD.increment("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.retries_exhausted")
      submission_id = job['args'][0]
      submission = DebtsApi::V0::DigitalDisputeSubmission.find(submission_id)
      submission&.register_failure("DigitalDisputeJob#perform: #{ex.message}")

      Rails.logger.error <<~LOG
        V0::DigitalDisputeJob retries exhausted:
        submission_id: #{submission_id}
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(submission_id)
      Rails.logger.info("Starting DigitalDisputeJob for submission_id #{submission_id}")
      submission = DebtsApi::V0::DigitalDisputeSubmission.find(submission_id)
      user_account = submission.user_account
      mpi_response = MPI::Service.new.find_profile_by_identifier(identifier: user_account.icn, identifier_type: MPI::Constants::ICN)
      user = OpenStruct.new(
        participant_id: mpi_response.profile.participant_id,
        ssn: mpi_response.profile.ssn,
        user_uuid: submission.user_uuid
      )

      DebtsApi::V0::DigitalDisputeDmcService.new(user, submission).call!

      submission.register_success
      in_progress_form(submission.user_uuid)&.destroy
    rescue => e
      Rails.logger.error("DigitalDisputeJob failed for submission_id #{submission_id}: #{e.message}")
      raise e
    end

    private

    def in_progress_form(user_uuid)
      InProgressForm.find_by(form_id: 'DISPUTE-DEBT', user_uuid:)
    end
  end
end
