# frozen_string_literal: true

require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfGenerator < ClaimsApi::ServiceBase
      EVSS_DOCUMENT_TYPE = 'L023'
      LOG_TAG = '526_v2_PDF_Generator_job'
      sidekiq_options expires_in: 48.hours, retry: true

      def perform(claim_id, middle_initial) # rubocop:disable Metrics/MethodLength
        log_job_progress(claim_id,
                         "526EZ PDF generator started for claim #{claim_id}")

        auto_claim = get_claim(claim_id)

        if Settings.claims_api.benefits_documents.use_mocks
          start_docker_container_job(auto_claim&.id, perform_async)
          return
        end

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        mapped_claim = pdf_mapper_service(auto_claim.form_data, get_pdf_data, auto_claim.auth_headers,
                                          middle_initial, auto_claim.created_at).map_claim
        pdf_string = generate_526_pdf(mapped_claim)

        if pdf_string.empty?
          log_job_progress(claim_id,
                           '526EZ PDF generator failed to return PDF string for claim')

          set_errored_state_on_claim(auto_claim)
        elsif pdf_string
          log_job_progress(claim_id,
                           '526EZ PDF generator PDF string returned')

          path = ::Common::FileHelpers.generate_random_file(pdf_string)
          file_name = "#{path.split('tmp/')[1]}.pdf"

          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })

          log_job_progress(claim_id,
                           "526EZ PDF generator Uploaded 526EZ PDF #{file_name} to S3")

          auto_claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          save_auto_claim!(auto_claim, auto_claim.status)

          ::Common::FileHelpers.delete_file_if_exists(path)
        end

        log_job_progress(claim_id,
                         '526EZ PDF generator job finished')
        start_docker_container_job(auto_claim&.id) if auto_claim.status != errored_state_value
      rescue Faraday::ParsingError, Faraday::TimeoutError => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        error_status = get_error_status_code(e)

        log_job_progress(claim_id,
                         "526EZ PDF generator faraday error #{e.class}: #{error_status} #{auto_claim&.evss_response}")

        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)
        error_status = get_error_status_code(e)

        log_job_progress(claim_id,
                         "526EZ PDF generator errored #{e.class}: #{error_status} #{auto_claim&.evss_response}")
        raise e
      rescue => e
        set_errored_state_on_claim(auto_claim)
        set_evss_response(auto_claim, e)

        log_job_progress(claim_id,
                         "526EZ PDF generator errored #{e.class}: #{e}")
        raise e
      end

      private

      def start_docker_container_job(auto_claim)
        docker_container_service.perform_async(auto_claim)
      end

      def docker_container_service
        ClaimsApi::V2::DisabilityCompensationDockerContainerUpload
      end

      def pdf_mapper_service(form_data, pdf_data, auth_headers, middle_initial, created_at)
        ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_data, pdf_data, auth_headers, middle_initial,
                                                           created_at)
      end

      # Docker container wants data: but not attributes:
      def generate_526_pdf(mapped_data)
        pdf = get_pdf_data
        pdf[:data] = mapped_data[:data][:attributes]
        client = PDFClient.new(pdf)
        client.generate_pdf
      end

      def get_pdf_data
        {
          data: {}
        }
      end
    end
  end
end
