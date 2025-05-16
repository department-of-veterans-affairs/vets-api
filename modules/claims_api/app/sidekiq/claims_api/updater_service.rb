# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/claim_logger'

module ClaimsApi
  class UpdaterService
    extend ActiveSupport::Concern
    include Sidekiq::Job

    sidekiq_retries_exhausted do |message|
      ClaimsApi::Logger.log(
        'claims_api_retries_exhausted',
        claim_id: message['args'].last,
        detail: "Job retries exhausted for #{message['class']}",
        error: message['error_message']
      )
    end

    def bgs_headers(claim_id)
      return if claim_id.nil?

      claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)
      return if claim.nil? || !claim.auth_headers.is_a?(Hash)

      ssn = claim.auth_headers['va_eauth_pnid'] unless claim.auth_headers['va_eauth_pnid'].nil?
      pid = claim.auth_headers['va_eauth_pid'] unless claim.auth_headers['va_eauth_pid'].nil?
      {
        'ssn' => ssn,
        'participant_id' => pid
      }
    end
  end
end
