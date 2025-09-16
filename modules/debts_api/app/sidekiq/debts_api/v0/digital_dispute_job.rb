require 'debts_api/v0/digital_dispute_submission_service'

module DebtsApi
  class V0::DigitalDisputeJob
    include Sidekiq::Worker

    def perform(submission_id)
      submission = DebtsApi::V0::DigitalDisputeSubmission.find(submission_id)
      user_account = submission.user_account
      mpi_response = MPI::Service.new.find_profile_by_identifier(identifier: user_account.icn, identifier_type: MPI::Constants::ICN)
      user = OpenStruct.new(participant_id: mpi_response.profile.participant_id, ssn: mpi_response.profile.ssn)

      DebtsApi::V0::DigitalDisputeDmcService.new(user, submission.id).process_submission
    rescue StandardError => e
      Rails.logger.error("DigitalDisputeJob failed for submission_id #{submission_id}: #{e.message}")
      raise e
    end
  end
end
