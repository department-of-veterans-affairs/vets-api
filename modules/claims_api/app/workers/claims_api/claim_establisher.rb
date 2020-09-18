# frozen_string_literal: true

require 'sidekiq'
require 'evss/disability_compensation_form/service_exception'
require 'evss/disability_compensation_form/service'
require 'sentry_logging'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker
    include SentryLogging

    def perform(auto_claim_id)
      auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)

      form_data = auto_claim.to_internal
      auth_headers = auto_claim.auth_headers

      response = service(auth_headers).submit_form526(form_data)
      auto_claim.evss_id = response.claim_id
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
      auto_claim.save
    rescue ::EVSS::DisabilityCompensationForm::ServiceException => e
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      auto_claim.evss_response = e.messages
      auto_claim.save
      log_exception_to_sentry(e)
    rescue ::Common::Exceptions::BackendServiceException => e
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
      auto_claim.evss_response = [{ 'key' => e.status_code, 'severity' => 'FATAL', 'text' => e.original_body }]
      auto_claim.save
      log_exception_to_sentry(e)
    end

    private

    def service(auth_headers)
      if Settings.claims_api.disability_claims_mock_override && !auth_headers['Mock-Override']
        ClaimsApi::DisabilityCompensation::MockOverrideService.new(
          auth_headers
        )
      else
        EVSS::DisabilityCompensationForm::Service.new(
          auth_headers
        )
      end
    end
  end
end
