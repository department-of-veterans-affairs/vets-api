# frozen_string_literal: true

module ClaimsApi
  class UpdaterService
    extend ActiveSupport::Concern

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
