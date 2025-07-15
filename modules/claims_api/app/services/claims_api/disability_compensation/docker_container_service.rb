# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'
require 'fes_service/base'

module ClaimsApi
  module DisabilityCompensation
    class DockerContainerService < ServiceBase
      LOG_TAG = '526_v2_Docker_Container_service'

      def upload(claim_id)
        auto_claim = get_claim(claim_id)

        log_job_progress(claim_id, 'Docker container service started', auto_claim.transaction_id)

        update_auth_headers(auto_claim) if auto_claim.transaction_id.present?

        # Use EVSS mapper for both services - assuming FES accepts the same data structure
        claim_data = get_evss_data(auto_claim)
        service_name = use_fes_service? ? 'FES' : 'EVSS Docker container'

        log_job_progress(claim_id, "Submitting mapped data to #{service_name}", auto_claim.transaction_id)

        submission_response = if use_fes_service?
                                submission_service.submit(auto_claim, claim_data)
                              else
                                submission_service.submit(auto_claim, claim_data, false)
                              end

        log_job_progress(claim_id, "Successfully submitted to #{service_name} with response: #{submission_response}",
                         auto_claim.transaction_id)

        # update with the claim_id returned
        auto_claim.update!(evss_id: submission_response[:claimId])
      rescue => e
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.evss_response = e.errors if e.methods.include?(:errors)
        auto_claim.save
        raise e
      end

      private

      def update_auth_headers(auto_claim)
        updated_auth_headers = auto_claim.auth_headers
        updated_auth_headers['va_eauth_service_transaction_id'] = auto_claim.transaction_id
        auto_claim.update!(auth_headers: updated_auth_headers)
      end

      def get_evss_data(auto_claim)
        evss_mapper_service(auto_claim).map_claim
      end

      def submission_service
        if use_fes_service?
          ClaimsApi::FesService::Base.new
        else
          ClaimsApi::EVSSService::Base.new
        end
      end

      def use_fes_service?
        Flipper.enabled?(:claims_api_v2_lh_fes_auto_establish_claim_enabled)
      end

      def evss_mapper_service(auto_claim)
        ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim)
      end
    end
  end
end
