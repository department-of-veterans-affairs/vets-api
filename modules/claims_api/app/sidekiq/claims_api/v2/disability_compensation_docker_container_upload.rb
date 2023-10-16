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

      def perform(claim_id, file_number)
        @claim = get_claim(claim_id)
        @file_number = file_number

        log_job_progress('dis_comp_evss', 
          claim_id, 
          'EVSS job started')

        if @claim.evss_id.nil?
          evss_data = evss_mapper_service.map_claim
          log_job_progress('dis_comp_evss', 
            claim_id, 
            'Submitting to EVSS')

          evss_res = evss_service.submit(@claim, evss_data)
          log_job_progress('dis_comp_evss', 
            claim_id, 
            'Successfully submitted to EVSS')

          @claim.update(evss_id: evss_res[:claimId])
        else
          self.class.perform_in(30.minutes, claim_id)
        end

        if @claim.status != 'errored' && !@claim.evss_id.nil?
          start_vbms_job
        end

      rescue ::Common::Exceptions::BackendServiceException => e
        log_job_progress('dis_comp_evss', 
          claim_id, 
          "Docker container submit failed for claimId #{@claim&.id}: #{e.original_body}")
        set_errored_state(e, @claim.id)
        raise e
      rescue => e
        log_job_progress('dis_comp_evss', 
          claim_id, 
          "Docker container submit failed for claimId #{@claim&.id}: #{e.detailed_message}")
        set_errored_state(e, @claim.id)
        raise e
      end

      private

      def start_vbms_job
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