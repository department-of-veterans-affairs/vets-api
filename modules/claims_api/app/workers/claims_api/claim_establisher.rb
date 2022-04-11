# frozen_string_literal: true

require 'sidekiq'
require 'evss/disability_compensation_form/service_exception'
require 'evss/disability_compensation_form/service'
require 'sentry_logging'
require 'claims_api/claim_logger'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker
    include SentryLogging

    def perform(auto_claim_id) # rubocop:disable Metrics/MethodLength
      auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)

      form_data = auto_claim.to_internal
      auth_headers = auto_claim.auth_headers

      response = service(auth_headers).submit_form526(form_data)
      ClaimsApi::Logger.log('526',
                            claim_id: auto_claim_id,
                            vbms_id: response.claim_id)
      auto_claim.evss_id = response.claim_id
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
      auto_claim.evss_response = nil
      auto_claim.save!

      queue_flash_updater(auth_headers, auto_claim.flashes, auto_claim_id)
      queue_special_issues_updater(auth_headers, auto_claim.special_issues, auto_claim)
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

    def queue_special_issues_updater(auth_headers, special_issues_per_disability, auto_claim)
      return if special_issues_per_disability.blank?

      special_issues_per_disability.each do |disability|
        contention_id = {
          claim_id: auto_claim.evss_id,
          code: disability['code'],
          name: disability['name']
        }
        ClaimsApi::SpecialIssueUpdater.perform_async(bgs_user(auth_headers),
                                                     contention_id,
                                                     disability['special_issues'],
                                                     auto_claim.id)
      end
    end

    def queue_flash_updater(auth_headers, flashes, auto_claim_id)
      return if flashes.blank?

      ClaimsApi::FlashUpdater.perform_async(bgs_user(auth_headers), flashes, auto_claim_id)
    end

    def service(auth_headers)
      if Settings.claims_api.disability_claims_mock_override && !auth_headers['Mock-Override']
        ClaimsApi::DisabilityCompensation::MockOverrideService.new(auth_headers)
      else
        EVSS::DisabilityCompensationForm::Service.new(auth_headers)
      end
    end

    def bgs_user(auth_headers)
      {
        'ssn' => auth_headers['va_eauth_pnid'],
        'participant_id' => auth_headers['va_eauth_pid']
      }
    end
  end
end
