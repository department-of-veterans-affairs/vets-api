# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'claims_api/v2/disability_compensation_pdf_mapper'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationPdfGenerator < DisabilityCompensationClaimService
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      EVSS_DOCUMENT_TYPE = 'L023'

      def perform(claim_id, middle_initial, file_number) # rubocop:disable Metrics/MethodLength
        log_job_progress('dis_comp_pdf_generator',
                         claim_id,
                         '526EZ PDF generator started')

        @claim = get_pending_claim(claim_id)

        pdf_data = get_pdf_data
        mapped_claim = pdf_mapper_service(@claim.form_data, pdf_data, @claim.auth_headers, middle_initial).map_claim
        pdf_string = generate_526_pdf(mapped_claim)

        if pdf_string.empty?
          log_job_progress('dis_comp_pdf_generator',
                           @claim.id,
                           '526EZ PDF generator failed')

          set_errored_state('PDF string came back empty', @claim.id)
        elsif pdf_string
          log_job_progress('dis_comp_pdf_generator',
                           @claim.id,
                           '526EZ PDF generator PDF upload completed')

          file_name = "#{SecureRandom.hex}.pdf"
          path = ::Common::FileHelpers.generate_temp_file(pdf_string, file_name)
          upload = ActionDispatch::Http::UploadedFile.new({
                                                            filename: file_name,
                                                            type: 'application/pdf',
                                                            tempfile: File.open(path)
                                                          })
          # Sets fle_data on the claim, @claim.file_data
          # Example:
          # {"filename"=>"cd04fc6704292a0c9851d872c3583c9e.pdf", "doc_type"=>"L023", "description"=>nil}
          @claim.set_file_data!(upload, EVSS_DOCUMENT_TYPE)
          @claim.save!

          log_job_progress('dis_comp_pdf_generator',
                           @claim.id,
                           "526EZ PDF generator Uploaded 526EZ PDF #{file_name} to S3")

          ::Common::FileHelpers.delete_file_if_exists(path)

        end

        start_evss_job(file_number) if @claim.status != 'errored'
      rescue ::Common::Exceptions::BackendServiceException => e
        set_errored_state(e, @claim.id)
        log_job_progress('dis_comp_pdf_generator',
                         @claim.id,
                         "526EZ PDF generator errored #{e.status_code} #{e.original_body}")

        reschedule_job(claim_id, middle_initial, file_number)
        raise e
      rescue => e
        set_errored_state(e, @claim.id)
        log_job_progress('dis_comp_pdf_generator',
                         @claim.id,
                         "526EZ PDF generator errored #{e}")

        reschedule_job
        raise e
      end

      private

      def reschedule_job(claim_id, middle_initial, file_number)
        self.class.perform_in(30.minutes, [claim_id, middle_initial, file_number])
      end

      def start_evss_job(file_number)
        ClaimsApi::V2::DisabilityCompensationDockerContainerUpload.perform_async(@claim.id, file_number)
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
