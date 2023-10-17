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
        byebug
        @claim = get_claim(claim_id)
        @file_number = file_number

        log_job_progress('dis_comp_evss',
                         @claim&.id,
                         'EVSS job started')

        if @claim.evss_id.nil?
          evss_data = evss_mapper_service.map_claim
          log_job_progress('dis_comp_evss',
                           @claim&.id,
                           'Submitting to EVSS')

          evss_res = evss_service.submit(@claim, evss_data)
          log_job_progress('dis_comp_evss',
                           @claim&.id,
                           'Successfully submitted to EVSS')

          @claim.update(evss_id: evss_res[:claimId])

          start_vbms_job if @claim.status != 'errored' && !@claim.evss_id.nil?
        # We have an EVSS id but an error, which happened after setting EVSS ID
        elsif @claim.status == 'errored'
          self.class.perform_in(30.minutes, [@claim&.id, @file_number])
        end

      rescue ::Common::Exceptions::BackendServiceException => e
        log_job_progress('dis_comp_evss',
                         @claim&.id,
                         "Docker container submit failed for claimId #{@claim&.id}: #{e.original_body}")
        set_errored_state(e, @claim.id)
        raise e
      rescue => e
        log_job_progress('dis_comp_evss',
                         @claim&.id,
                         "Docker container job failed before completing for claimId #{@claim&.id}: #{e.detailed_message}")
        set_errored_state(e, @claim.id)
        raise e
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
