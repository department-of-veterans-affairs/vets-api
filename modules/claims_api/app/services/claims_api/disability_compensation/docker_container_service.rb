# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'

module ClaimsApi
  module DisabilityCompensation
    class DockerContainerService < ClaimsApi::Service
      LOG_TAG = '526_v2_Docker_Container_service'

      def upload(claim_id)
        log_service_progress(claim_id, 'docker_service',
                             'Docker container service started')

        auto_claim = get_claim(claim_id)
        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        evss_data = evss_mapper_service(auto_claim, veteran_file_number(auto_claim)).map_claim

        log_service_progress(claim_id, 'docker_service',
                             'Submitting mapped data to Docker container')

        evss_res = evss_service.submit(auto_claim, evss_data)

        log_service_progress(claim_id, 'docker_service',
                             "Successfully submitted to Docker container with response: #{evss_res}")
        # update with the evss_id returned
        auto_claim.update!(evss_id: evss_res[:claimId])
        # clear out the evss_response value on successful submssion to docker container
        clear_evss_response_for_claim(auto_claim)
        # queue flashes service
        queue_flash_updater(auto_claim.flashes, auto_claim&.id)
        # now upload to benefits documents
        start_bd_uploader_job(auto_claim) if auto_claim.status != errored_state_value
      end
    end
  end
end
