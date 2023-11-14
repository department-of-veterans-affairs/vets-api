# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'claims_api/v2/disability_compensation_evss_mapper'
require 'evss_service/base'

module ClaimsApi
  module V2
    class DisabilityCompensationDockerContainerUpload < DisabilityCompensationClaimServiceBase
      LOG_TAG = '526_v2_Docker_Container_job'

      def perform(claim_id) # rubocop:disable Metrics/MethodLength
        log_job_progress(LOG_TAG,
                         claim_id,
                         'Docker container job started')

        auto_claim = get_claim(claim_id)
        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        evss_data = evss_mapper_service(auto_claim, veteran_file_number(auto_claim)).map_claim

        log_job_progress(LOG_TAG,
                         claim_id,
                         'Submitting mapped data to Docker container')

        evss_res = evss_service.submit(auto_claim, evss_data)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "Successfully submitted to Docker container with response: #{evss_res}")
        # update with the evss_id returned
        auto_claim.update(evss_id: evss_res[:claimId])
        # clear out the evss_response value on successful submssion to docker container
        clear_evss_response_for_claim(auto_claim)
        # queue flashes job
        queue_flash_updater(auto_claim.flashes, auto_claim&.id)
        # now upload to benefits documents
        start_bd_uploader_job(auto_claim) if auto_claim.status != errored_state_value
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        error_status = get_error_status_code(e)
        error_message = get_error_message(e)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "Docker container job errored #{e.class}: #{error_status} #{error_message}")

        log_exception_to_sentry(e)

        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        error_message = get_error_message(e)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "Docker container job errored #{e.class}: #{error_message}")
        log_exception_to_sentry(e)
        # if will_retry?
        if will_retry?(e)
          raise e
        else # form526.submit.noRetryError OR form526.InProcess error retruned
          {}
        end
      rescue => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        log_job_progress(LOG_TAG,
                         claim_id,
                         "Docker container job errored #{e.class}: #{e&.detailed_message}")
        log_exception_to_sentry(e)

        raise e
      end

      private

      def queue_flash_updater(flashes, auto_claim_id)
        return if flashes.blank?

        ClaimsApi::FlashUpdater.perform_async(flashes, auto_claim_id)
      end

      def set_evss_response(auto_claim, error)
        error_message = get_error_message(error)
        error_key = get_error_key(error_message)
        error_text = get_error_text(error_message)

        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.evss_response = [
          { 'key' => error_key,
            'severity' => 'FATAL',
            'text' => error_text }
        ]
        auto_claim.save!
      end

      def start_bd_uploader_job(auto_claim)
        bd_service.perform_async(auto_claim.id)
      end

      def bd_service
        ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader
      end

      def evss_mapper_service(auto_claim, file_number)
        ClaimsApi::V2::DisabilityCompensationEvssMapper.new(auto_claim, file_number)
      end

      def veteran_file_number(auto_claim)
        auto_claim.auth_headers['va_eauth_birlsfilenumber']
      end

      def evss_service
        ClaimsApi::EVSSService::Base.new
      end
    end
  end
end
