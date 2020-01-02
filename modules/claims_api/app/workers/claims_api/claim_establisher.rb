# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker

    def perform(auto_claim_id)
      auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)

      form_data = auto_claim.to_internal
      auth_headers = auto_claim.auth_headers

      begin
        response = service(auth_headers).submit_form526(form_data)
        auto_claim.evss_id = response.claim_id
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
        auto_claim.save
      rescue ::Common::Exceptions::BackendServiceException => e
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.save
        raise e
      end
    end

    private

    def service(auth_headers)
      if Settings.claims_api.disability_claims_mock_override && !auth_headers['Mock-Override']
        ClaimsApi::DisabilityCompensation::MockOverrideService.new(
          auth_headers
        )
      else
        EVSS::DisabilityCompensationForm::ServiceAllClaim.new(
          auth_headers
        )
      end
    end
  end
end
