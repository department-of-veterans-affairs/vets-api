# frozen_string_literal: true

require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module DisabilityCompensation
    class PdfGenerationService < ServiceBase
      EVSS_DOCUMENT_TYPE = 'L023'
      LOG_TAG = '526_v2_PDF_Generator_service'

      def generate(claim_id, middle_initial) # rubocop:disable Metrics/MethodLength
        auto_claim = get_claim(claim_id)

        log_job_progress(auto_claim.id, "526EZ PDF generator started for claim #{auto_claim.id}",
                         auto_claim.transaction_id)

        mapped_claim = generate_mapped_claim(auto_claim, middle_initial)
        pdf_string = generate_526_pdf(mapped_claim)

        if pdf_string.empty?
          log_job_progress(auto_claim.id, '526EZ PDF generator failed to return PDF string for claim',
                           auto_claim.transaction_id)

          set_errored_state_on_claim(auto_claim)
        elsif pdf_string
          log_job_progress(auto_claim.id, '526EZ PDF generator PDF string returned', auto_claim.transaction_id)

          path = ::Common::FileHelpers.generate_random_file(pdf_string)
          file_name = "#{path.split('tmp/')[1]}.pdf"

          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })

          log_job_progress(auto_claim.id, "526EZ PDF generator Uploaded 526EZ PDF #{file_name} to S3",
                           auto_claim.transaction_id)

          auto_claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          auto_claim.save!

          ::Common::FileHelpers.delete_file_if_exists(path)
        end

        log_job_progress(auto_claim.id, '526EZ PDF generator job finished', auto_claim.transaction_id)

        auto_claim.status
      end

      def generate_mapped_claim(auto_claim, middle_initial)
        pdf_mapper_service(auto_claim.form_data, get_pdf_data, auto_claim.auth_headers,
                           middle_initial, auto_claim.created_at).map_claim
      end

      private

      def pdf_mapper_service(form_data, pdf_data, auth_headers, middle_initial, created_at)
        ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_data, pdf_data, auth_headers, middle_initial,
                                                           created_at)
      end

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
