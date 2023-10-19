# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'
require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfGenerator
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      EVSS_DOCUMENT_TYPE = 'L023'

      def perform(claim_id, middle_initial, file_number) # rubocop:disable Metrics/MethodLength
        ClaimsApi::Logger.log('********** 526 v2 PDf Generator job',
                              claim_id:,
                              detail: "526EZ PDF generator started for claim #{claim_id}")

        auto_claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)

        pdf_data = get_pdf_data
        mapped_claim = pdf_mapper_service(auto_claim.form_data, pdf_data, auto_claim.auth_headers,
                                          middle_initial).map_claim
        pdf_string = generate_526_pdf(mapped_claim)

        if pdf_string.empty?
          ClaimsApi::Logger.log('526 v2 PDf Generator job',
                                claim_id:,
                                detail: '526EZ PDF generator failed for claim')

          set_errored_state(claim_id)
          # restart?
        elsif pdf_string
          ClaimsApi::Logger.log('526 v2 PDf Generator job',
                                claim_id:,
                                detail: '526EZ PDF generator PDF string returned')

          file_name = "#{SecureRandom.hex}.pdf"
          path = ::Common::FileHelpers.generate_temp_file(pdf_string, file_name)
          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })

          ClaimsApi::Logger.log('526 v2 PDf Generator job',
                                claim_id:,
                                detail: "526EZ PDF generator Uploaded 526EZ PDF #{file_name} to S3")

          auto_claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          auto_claim.save!

          ::Common::FileHelpers.delete_file_if_exists(path)

        end

        start_evss_job(auto_claim&.id, file_number) if auto_claim.status != 'errored'

        ClaimsApi::Logger.log('********** 526 v2 PDf Generator job done',
                              claim_id:,
                              detail: '526EZ PDF generator job finished')
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_errored_state(claim_id)
        ClaimsApi::Logger.log('526 v2 PDf Generator job',
                              claim_id:,
                              detail: "526EZ PDF generator faraday errored #{e.status_code} #{e.original_body}")

        raise e
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state(claim_id)
        ClaimsApi::Logger.log('526 v2 PDf Generator job',
                              claim_id:,
                              detail: "526EZ PDF generator errored #{e.status_code} #{e.original_body}")

        raise e
        # {} # bad data so it will not pass until we fix
      rescue => e
        set_errored_state(claim_id)
        ClaimsApi::Logger.log('526 v2 PDf Generator job',
                              claim_id:,
                              detail: "526EZ PDF generator errored #{e}")

        raise e
        # {} # Permanent failures, don't retry
      end

      private

      def set_errored_state(claim_id)
        auto_claim = ClaimsApi::AutoEstablishedClaim.find(claim_id)

        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
        auto_claim.save!
      end

      def start_evss_job(auto_claim, file_number)
        ClaimsApi::V2::DisabilityCompensationDockerContainerUpload.perform_async(auto_claim, file_number)
      end

      def pdf_mapper_service(form_data, pdf_data, auth_headers, middle_initial)
        ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_data, pdf_data, auth_headers, middle_initial)
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
