# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'claims_api/v2/disability_compensation_fes_mapper'
require 'evss_service/base'
require 'fes_service/base'

module ClaimsApi
  module DisabilityCompensation
    class Form526EstablishmentService < ServiceBase
      LOG_TAG = '526_v2_form526_establishment_service'
      ASYNC = false

      def upload(claim_id)
        auto_claim = get_claim(claim_id)

        log_job_progress(claim_id, 'Form526 Establishment service started', auto_claim.transaction_id)

        update_auth_headers(auto_claim) if auto_claim.transaction_id.present?

        if Flipper.enabled?(:lighthouse_claims_api_v2_enable_FES)
          fes_data = get_fes_data(auto_claim)
          log_job_progress(claim_id, 'Submitting mapped data to FES', auto_claim.transaction_id)
          fes_res = fes_service.submit(auto_claim, fes_data, ASYNC)
          log_job_progress(claim_id, "Successfully submitted to FES with response: #{fes_res}",
                           auto_claim.transaction_id)
          # update with the evss_id returned
          auto_claim.update!(evss_id: fes_res[:claimId])
        else
          evss_data = get_evss_data(auto_claim)
          log_job_progress(claim_id, 'Submitting mapped data to Form 526 Establishment service',
                           auto_claim.transaction_id)
          evss_res = evss_service.submit(auto_claim, evss_data, ASYNC)
          log_job_progress(claim_id, "Successfully submitted to 526 Establishment service with response: #{evss_res}",
                           auto_claim.transaction_id)
          # update with the evss_id returned
          auto_claim.update!(evss_id: evss_res[:claimId])
        end
      rescue => e
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.evss_response = e.errors if e.methods.include?(:errors)
        auto_claim.save
        raise e
      end

      # rubocop:enable Metrics/MethodLength

      private

      def update_auth_headers(auto_claim)
        updated_auth_headers = auto_claim.auth_headers
        updated_auth_headers['va_eauth_service_transaction_id'] = auto_claim.transaction_id
        auto_claim.update!(auth_headers: updated_auth_headers)
      end

      def get_evss_data(auto_claim)
        evss_mapper_service(auto_claim).map_claim
      end

      def get_fes_data(auto_claim)
        fes_mapper_service(auto_claim).map_claim
      end
    end
  end
end
