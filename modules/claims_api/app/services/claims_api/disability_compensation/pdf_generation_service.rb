# frozen_string_literal: true

require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module DisabilityCompensation
    class PdfGenerationService < ClaimsApi::Service
      EVSS_DOCUMENT_TYPE = 'L023'
      LOG_TAG = '526_v2_PDF_Generator_job'

      def generate(claim_id, middle_initial) # rubocop:disable Metrics/MethodLength
        log_service_progress(claim_id, 'pdf',
                             "526EZ PDF generator started for claim #{claim_id}")

        auto_claim = get_claim(claim_id)

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        mapped_claim = pdf_mapper_service(auto_claim.form_data, get_pdf_data, auto_claim.auth_headers,
                                          middle_initial, auto_claim.created_at).map_claim
        pdf_string = generate_526_pdf(mapped_claim)

        if pdf_string.empty?
          log_service_progress(claim_id, 'pdf',
                               '526EZ PDF generator failed to return PDF string for claim')

          set_errored_state_on_claim(auto_claim)
        elsif pdf_string
          log_service_progress(claim_id, 'pdf',
                               '526EZ PDF generator PDF string returned')

          file_name = "#{SecureRandom.hex}.pdf"
          path = ::Common::FileHelpers.generate_temp_file(pdf_string, file_name)
          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })

          log_service_progress(claim_id, 'pdf',
                               "526EZ PDF generator Uploaded 526EZ PDF #{file_name} to S3")

          auto_claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          save_auto_claim!(auto_claim, auto_claim.status)

          ::Common::FileHelpers.delete_file_if_exists(path)
        end

        log_service_progress(claim_id, 'pdf',
                             '526EZ PDF generator job finished')
      end
    end
  end
end
