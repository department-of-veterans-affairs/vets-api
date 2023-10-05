# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'claims_api/claim_logger'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfGenerator < ClaimsApi::V2::DisabilityCompensationClaimProcessor
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform(claim, target_veteran)
        byebug
        log_job_progress('dis_comp_pdf_generator', claim, '526EZ PDF generator started')

        pdf_data = get_pdf_data
        pdf_mapper_service(claim.form_data, pdf_data, target_veteran).map_claim

        pdf_string = generate_526_pdf(pdf_data)

        if pdf_string.empty?
          log_job_progress('dis_comp_pdf_generator', claim, '526EZ PDF generator failed')
        elsif pdf_string
          log_job_progress('dis_comp_pdf_generator', claim, '526EZ PDF generator PDF completed')
          file_name = "#{SecureRandom.hex}.pdf"
          path = ::Common::FileHelpers.generate_temp_file(pdf_string, file_name)
          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })
          claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          claim.save!
          log_job_progress('dis_comp_pdf_generator', claim, '526EZ PDF generator Uploaded 526EZ PDF to S3')
          ::Common::FileHelpers.delete_file_if_exists(path)
          # docker = ClaimsApi::DockerContainer.perform_async
          # @uploader ||= ClaimsApi::SupportingDocumentUploader.new(id)
        end
        log_job_progress('dis_comp_pdf_generator', claim, '526EZ PDF generator succeeded')
      end

      private

      def start_docker_container_upload()
        #ClaimsApi::DockerContainer.perform_async
      end

      def pdf_mapper_service(claim, pdf_data, target_veteran)
        ClaimsApi::V2::DisabilityCompensationPdfMapper.new(claim, pdf_data, target_veteran)
      end

      def generate_526_pdf(pdf_data)
        pdf_data[:data] = pdf_data[:data][:attributes]
        client = PDFClient.new(pdf_data.to_json)
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