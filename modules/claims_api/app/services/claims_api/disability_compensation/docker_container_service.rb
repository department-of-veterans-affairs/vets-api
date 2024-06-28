# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'

module ClaimsApi
  module DisabilityCompensation
    class DockerContainerService < ClaimsApi::Service
      def upload(claim_id)
        log_service_progress(claim_id, 'docker_service',
                             'Docker container service started')

        auto_claim = get_claim(claim_id)

        evss_data = get_evss_data(auto_claim)

        log_service_progress(claim_id, 'docker_service',
                             'Submitting mapped data to Docker container')

        evss_res = evss_service.submit(auto_claim, evss_data, false)

        log_service_progress(claim_id, 'docker_service',
                             "Successfully submitted to Docker container with response: #{evss_res}")
        # update with the evss_id returned
        auto_claim.update!(evss_id: evss_res[:claimId])
      end

      def get_evss_data(auto_claim)
        evss_mapper_service(auto_claim, veteran_file_number(auto_claim)).map_claim
      end
    end
  end
end
