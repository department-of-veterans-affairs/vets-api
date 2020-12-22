# frozen_string_literal: true

require 'sidekiq'
require 'evss/disability_compensation_form/service_exception'
require 'evss/disability_compensation_form/service'
require 'bgs/auth_headers'
require 'sentry_logging'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker
    include SentryLogging

    def perform(auto_claim_id)
      auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)

      form_data = auto_claim.to_internal
      auth_headers = auto_claim.auth_headers
      flashes = auto_claim.flashes

      response = service(auth_headers).submit_form526(form_data)
      auto_claim.evss_id = response.claim_id
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
      auto_claim.save

      queue_flash_updater(auth_headers, flashes, auto_claim_id) if flashes.present?
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

    def queue_flash_updater(auth_headers, flashes, auto_claim_id)
      ClaimsApi::FlashUpdater.perform_async(bgs_user(auth_headers), flashes, auto_claim_id: auto_claim_id)
    end

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

    def bgs_user(auth_headers)
      user = OpenStruct.new(ssn: auth_headers['va_eauth_pnid'],
                            uuid: nil,
                            email: nil,
                            icn: nil,
                            common_name: nil)
      return user if auth_headers['va_bgs_authorization'].blank?

      bgs_auth_headers = JSON.parse(auth_headers['va_bgs_authorization'])
      user.uuid = bgs_auth_headers['external_uid']
      user.email = bgs_auth_headers['external_key']

      user
    end
  end
end
