# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfGenerator < DisabilityCompensationClaimProcessor
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform(claim_id)
        log_job_progress('dis_comp_pdf_generator', 
            claim_id, 
            '526EZ PDF generator started')

        @claim = get_claim(claim_id)

        byebug

        pdf_data = get_pdf_data
        pdf_mapper_service(@claim.form_data, pdf_data, @claim.auth_headers).map_claim

        pdf_string = generate_526_pdf(pdf_data, @claim.form_data)

        if pdf_string.empty?
          log_job_progress('dis_comp_pdf_generator', 
            claim.id, 
            '526EZ PDF generator failed')
        elsif pdf_string
          log_job_progress('dis_comp_pdf_generator', 
            claim.id, 
            '526EZ PDF generator PDF upload completed')

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
        end

        byebug

      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state(e)
        log_job_progress('dis_comp_pdf_generator', 
          claim_id, 
          "526EZ PDF generator errored #{e.status_code} #{e.original_body}")
        raise e
      rescue e
        set_errored_state(e)
        log_job_progress('dis_comp_pdf_generator', 
          claim_id, 
          "526EZ PDF generator errored #{e}")
        raise e

        unless @claim.status == 'errored'
          start_evss_job
        end
      end

      private

      def start_evss_job
        # docker = ClaimsApi::DockerContainer.perform_async(@claim.id)
        # @uploader ||= ClaimsApi::SupportingDocumentUploader.new(@claim.id)
      end

      def set_errored_state(error)
        @claim.status = ClaimsApi::V2::AutoEstablishedClaim::ERRORED
        @claim.evss_response = [{ 'key' => error.status_code, 'severity' => 'FATAL', 'text' => error.original_body }]
        @claim.save
      end

      def pdf_mapper_service(form_data, pdf_data, auth_headers)
        ClaimsApi::V2::DisabilityCompensationPdfMapper.new(form_data, pdf_data, auth_headers)
      end

      def start_docker_container_upload()
        #ClaimsApi::DockerContainer.perform_async
      end

      def generate_526_pdf(pdf_data, form_data)
        pdf_data[:data] = form_data
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