# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'

module ClaimsApi
  module DisabilityCompensation
    class DockerContainerService < ServiceBase
      LOG_TAG = '526_v2_Docker_Container_service'

      def upload(claim_id)
        auto_claim = get_claim(claim_id)

        log_job_progress(claim_id, 'Docker container service started', auto_claim.transaction_id)

        update_auth_headers(auto_claim) if auto_claim.transaction_id.present?

        evss_data = get_evss_data(auto_claim)

        log_job_progress(claim_id, 'Submitting mapped data to Docker container', auto_claim.transaction_id)

        evss_res = evss_service.submit(auto_claim, evss_data, false)

        log_job_progress(claim_id, "Successfully submitted to Docker container with response: #{evss_res}",
                         auto_claim.transaction_id)

        # update with the evss_id returned
        auto_claim.update!(evss_id: evss_res[:claimId])
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
    end
  end
end
