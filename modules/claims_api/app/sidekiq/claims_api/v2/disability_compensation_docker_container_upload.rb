# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'
require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationDockerContainerUpload
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform(claim_id, file_number) # rubocop:disable Metrics/MethodLength
        ClaimsApi::Logger.log('********** 526 v2 Docker Container job',
                              claim_id:,
                              detail: 'Docker container job started')

        auto_claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)

        if auto_claim.evss_id.nil?
          evss_data = evss_mapper_service(auto_claim, file_number).map_claim

          ClaimsApi::Logger.log('526 v2 Docker Container job',
                                claim_id:,
                                detail: 'Submitting to Docker container')

          evss_res = evss_service.submit(auto_claim, evss_data)

          ClaimsApi::Logger.log('526 v2 Docker container job',
                                claim_id:,
                                detail: "Successfully submitted to Docker container with response: #{evss_res}")

          auto_claim.update(evss_id: evss_res[:claimId])
        end

        start_vbms_job(auto_claim) if auto_claim.status != 'errored' && !auto_claim.evss_id.nil?
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_evss_errored_state(claim_id)
        set_evss_response(auto_claim, e)
        ClaimsApi::Logger.log('526 v2 Docker Container job',
                              claim_id:,
                              detail: "526EZ PDF generator errored #{e.status_code} #{e.original_body}")

        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_evss_errored_state(claim_id)
        set_evss_response(auto_claim, e)
        ClaimsApi::Logger.log('526 v2 Docker Container job',
                              claim_id:,
                              detail: "Submit failed for claimId #{auto_claim&.id}: #{e.original_body}")
        # {}
        raise e
      rescue => e
        set_evss_errored_state(claim_id)
        set_evss_response(auto_claim, e)
        ClaimsApi::Logger.log('526 v2 Docker Container job',
                              claim_id:,
                              detail: "Submit failed for claimId #{auto_claim&.id}: #{e.detailed_message}")

        # {}
        raise e
      end

      private

      def set_evss_errored_state(claim_id)
        auto_claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)

        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.save!
      end

      def set_evss_response(auto_claim, error)
        error_status = get_error_status_code(error)
        error_message = get_error_message(error)

        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.evss_response = [{ 'key' => error_status, 'severity' => 'FATAL', 'text' => error_message }]
        auto_claim.save!
      end

      def get_error_status_code(error)
        if error.respond_to? :status_code
          error.status_code
        else
          "No status code for error: #{error}"
        end
      end

      def get_error_message(error)
        if error.respond_to? :original_body
          error.original_body
        elsif error.respond_to? :messagae
          error.message
        elsif error.is_a?(String)
          error
        end
      end

      def start_vbms_job(auto_claim)
        vbms_service.new.perform_async(auto_claim.id)
      end

      def vbms_service
        ClaimsApi::V2::DisabilityCompensationVBMSUploader
      end

      def evss_mapper_service(auto_claim, file_number)
        ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim, file_number)
      end

      def evss_service
        ClaimsApi::EVSSService::Base.new
      end
    end
  end
end
