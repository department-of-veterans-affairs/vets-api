# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'claims_api/v1/disability_compensation_fes_mapper'
require 'fes_service/base'

module ClaimsApi
  module V1
    # rubocop:disable Metrics/MethodLength
    class Form526EstablishmentUpload < ClaimsApi::ServiceBase
      LOG_TAG = 'form_526_v1_establishment_upload'
      sidekiq_options expires_in: 48.hours, retry: true

      def perform(claim_id)
        log_job_progress(claim_id,
                         'Form 526 Est. job started')
        auto_claim = get_claim(claim_id)
        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        log_job_progress(claim_id,
                         'Submitting mapped data to Form 526 Est.')

        fes_data = v1_fes_mapper_service(auto_claim).map_claim
        fes_res = fes_service.submit(auto_claim, fes_data)

        log_job_progress(claim_id,
                         "Successfully submitted to Form 526 Est. with response: #{fes_res}")
        # update with the evss_id returned
        auto_claim.update!(evss_id: fes_res[:claimId])
        # clear out the evss_response value on successful submission to Form 526 Est.
        clear_evss_response_for_claim(auto_claim)
        # queue flashes job
        queue_flash_updater(auto_claim.flashes, auto_claim&.id)
        # now upload to benefits documents
        start_bd_uploader_job(auto_claim) if auto_claim.status != errored_state_value
      rescue Faraday::ParsingError, Faraday::TimeoutError => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        error_status = get_error_status_code(e)
        log_job_progress(claim_id,
                         "Form 526 Est. job errored #{e.class}: #{error_status} #{auto_claim&.evss_response}")
        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        log_job_progress(claim_id,
                         "Form 526 Est. job errored #{e.class}: #{auto_claim&.evss_response}")
        log_exception_to_rails e
        if will_retry?(auto_claim, e)
          raise e
        else
          # form526.submit.noRetryError OR form526.InProcess error returned
          {}
        end
      rescue => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e) if auto_claim.evss_response.blank?
        log_job_progress(claim_id,
                         "Form 526 Est. job errored #{e.class}: #{e&.detailed_message}")
        log_exception_to_rails e

        raise e
      end

      # rubocop:enable Metrics/MethodLength

      private

      def queue_flash_updater(flashes, auto_claim_id)
        return if flashes.blank?

        ClaimsApi::FlashUpdater.perform_async(flashes, auto_claim_id)
      end

      def start_bd_uploader_job(auto_claim)
        bd_service.perform_async(auto_claim.id, :v1)
      end

      def bd_service
        ClaimsApi::DisabilityCompensationBenefitsDocumentsUploader
      end
    end
  end
end
