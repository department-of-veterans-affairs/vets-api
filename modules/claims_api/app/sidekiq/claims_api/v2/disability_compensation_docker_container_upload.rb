# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'

module ClaimsApi
  module V2
    class DisabilityCompensationDockerContainerUpload < DisabilityCompensationClaimService
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform(claim_id, file_number) # rubocop:disable Metrics/MethodLength
        @claim = get_pending_claim(claim_id)
        @file_number = file_number

        log_job_progress('dis_comp_docker_container_job',
                         @claim&.id,
                         'Docker container job started')

        if @claim.evss_id.nil?
          evss_data = evss_mapper_service.map_claim
          log_job_progress('dis_comp_docker_container_job',
                           @claim&.id,
                           'Submitting to Docker container')

          evss_res = evss_service.submit(@claim, evss_data)
          log_job_progress('dis_comp_docker_container_job',
                           @claim&.id,
                           "Successfully submitted to Docker container with response: #{evss_res}")

          @claim.update(evss_id: evss_res[:claimId])
        end

        start_vbms_job if @claim.status != 'errored' && !@claim.evss_id.nil?
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_errored_state(e, @claim.id)
        log_job_progress('dis_comp_docker_container_job',
                         @claim.id,
                         "526EZ PDF generator errored #{e.status_code} #{e.original_body}")

        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state(e, claim_id)
        log_job_progress('dis_comp_docker_container_job',
                         claim_id,
                         "Docker container submit failed for claimId #{claim_id}: #{e.original_body}")
        {}
      rescue => e
        set_errored_state(e, claim_id)
        log_job_progress('dis_comp_docker_container_job',
                         claim_id,
                         "Docker container job failed for claimId #{claim_id}: #{e.detailed_message}")

        {}
      end

      private

      def start_vbms_job
        vbms_service.perform_async(@claim.id)
      end

      def vbms_service
        ClaimsApi::V2::DisabilityCompensationVBMSUploader
      end

      def evss_mapper_service
        ClaimsApi::V2::DisabilityCompensationEvssMapper.new(@claim, @file_number)
      end

      def evss_service
        ClaimsApi::EVSSService::Base.new
      end
    end
  end
end
