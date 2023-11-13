# frozen_string_literal: true

require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfGenerator < DisabilityCompensationClaimServiceBase
      EVSS_DOCUMENT_TYPE = 'L023'
      LOG_TAG = '526_v2_PDF_Generator_job'

      def perform(claim_id, middle_initial) # rubocop:disable Metrics/MethodLength
        log_job_progress(LOG_TAG,
                         claim_id,
                         "526EZ PDF generator started for claim #{claim_id}")

        auto_claim = get_claim(claim_id)

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        mapped_claim = pdf_mapper_service(auto_claim.form_data, get_pdf_data, auto_claim.auth_headers,
                                          middle_initial, auto_claim.created_at).map_claim
        pdf_string = generate_526_pdf(mapped_claim)

        if pdf_string.empty?
          log_job_progress(LOG_TAG,
                           claim_id,
                           '526EZ PDF generator failed to return PDF string for claim')

          set_errored_state_on_claim(auto_claim)
        elsif pdf_string
          log_job_progress(LOG_TAG,
                           claim_id,
                           '526EZ PDF generator PDF string returned')

          file_name = "#{SecureRandom.hex}.pdf"
          path = ::Common::FileHelpers.generate_temp_file(pdf_string, file_name)
          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })

          log_job_progress(LOG_TAG,
                           claim_id,
                           "526EZ PDF generator Uploaded 526EZ PDF #{file_name} to S3")

          auto_claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          auto_claim.save!

          ::Common::FileHelpers.delete_file_if_exists(path)
        end

        log_job_progress(LOG_TAG,
                         claim_id,
                         '526EZ PDF generator job finished')

        start_docker_container_job(auto_claim&.id) if auto_claim.status != errored_state_value
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_errored_state_on_claim(auto_claim)
        error_message = get_error_message(e)
        error_status = get_error_status_code(e)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "526EZ PDF generator faraday error #{e.class}: #{error_status} #{error_message}")
        log_exception_to_sentry(e)

        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state_on_claim(auto_claim)
        error_message = get_error_message(e)
        error_status = get_error_status_code(e)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "526EZ PDF generator errored #{e.class}: #{error_status} #{error_message}")
        log_exception_to_sentry(e)

        raise e
      rescue => e
        set_errored_state_on_claim(auto_claim)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "526EZ PDF generator errored #{e.class}: #{e}")
        log_exception_to_sentry(e)

        raise e
      end

      private

      def start_docker_container_job(auto_claim)
        docker_contaner_service.perform_async(auto_claim)
      end

      def docker_contaner_service
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
