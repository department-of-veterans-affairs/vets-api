# frozen_string_literal: true

require 'central_mail/datestamp_pdf'
require 'pdf_fill/filler'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm0781 < Job
      FORM_ID_0781 = '21-0781' # form id for PTSD
      FORM_ID_0781A = '21-0781a' # form id for PTSD Secondary to Personal Assault
      FORMS_METADATA = {
        FORM_ID_0781 => { docType: 'L228' },
        FORM_ID_0781A => { docType: 'L229' }
      }.freeze

      STATSD_KEY_PREFIX = 'worker.evss.submit_form0781'

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 10 will result in a run time of ~8 hours
      # This job is invoked from 526 background job
      RETRY = 10

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        Rails.logger.send(
          :error,
          "Failed all retries on SubmitForm0781 submit, last error: #{msg['error_message']}"
        )
        Metrics.new(STATSD_KEY_PREFIX, msg['jid']).increment_exhausted
      end

      # This method generates the PDF documents but does NOT send them anywhere.
      # It just generates them to the filesystem and returns the path to them to be used by other methods.
      #
      # @param submission_id [Integer] The {Form526Submission} id
      # @param uuid [String] The Central Mail UUID, not actually used,
      # but is passed along as the existing process_0781 function requires something here
      # @return [Hash] Returns a hash with the keys
      # `type` (to discern between if it is a 0781 or 0781a form) and
      # `file`, which is the generated file location
      def get_docs(submission_id, uuid)
        @submission_id = submission_id
        parsed_forms = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))
        file_type_and_file_objs = []
        { 'form0781' => FORM_ID_0781, 'form0781a' => FORM_ID_0781A }.each do |form_type_key, actual_form_types|
          if parsed_forms[form_type_key].present?
            file_type_and_file_objs << {
              type: actual_form_types,
              file: process_0781(submission.auth_headers, uuid, FORM_ID_0781, parsed_forms[form_type_key],
                                 upload: false)
            }
          end
        end
        file_type_and_file_objs
      end

      # Performs an asynchronous job for generating and submitting 0781 + 0781A PDF documents to VBMS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        Raven.tags_context(source: '526EZ-all-claims')
        super(submission_id)
        with_tracking('Form0781 Submission', submission.saved_claim_id, submission.id) do
          parsed_forms = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))

          # process 0781 and 0781a
          if parsed_forms['form0781'].present?
            process_0781(submission.auth_headers,
                         submission.submitted_claim_id, FORM_ID_0781, parsed_forms['form0781'])
          end
          if parsed_forms['form0781a'].present?
            process_0781(submission.auth_headers,
                         submission.submitted_claim_id, FORM_ID_0781A, parsed_forms['form0781a'])
          end
        end
      rescue => e
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(e)
        raise e
      end

      private

      def process_0781(auth_headers, evss_claim_id, form_id, form_content, upload: true)
        # generate and stamp PDF file
        pdf_path0781 = generate_stamp_pdf(form_content, evss_claim_id, form_id)
        upload ? upload_to_vbms(auth_headers, evss_claim_id, pdf_path0781, form_id) : pdf_path0781
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method CentralMail::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "VA.gov Submission" at the top of each page
      def generate_stamp_pdf(form_content, evss_claim_id, form_id)
        pdf_path = PdfFill::Filler.fill_ancillary_form(form_content, evss_claim_id, form_id)
        stamped_path = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VA.gov', x: 5, y: 5)
        CentralMail::DatestampPdf.new(stamped_path).run(
          text: 'VA.gov Submission',
          x: 510,
          y: 775,
          text_only: true
        )
      end

      def get_evss_claim_metadata(pdf_path, form_id)
        pdf_path_split = pdf_path.split('/')
        {
          doc_type: FORMS_METADATA[form_id][:docType],
          file_name: pdf_path_split.last
        }
      end

      def create_document_data(evss_claim_id, upload_data)
        EVSSClaimDocument.new(
          evss_claim_id:,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: upload_data[:doc_type]
        )
      end

      def upload_to_vbms(auth_headers, evss_claim_id, pdf_path, form_id)
        upload_data = get_evss_claim_metadata(pdf_path, form_id)
        document_data = create_document_data(evss_claim_id, upload_data)

        raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

        if Flipper.enabled?(:disability_compensation_lighthouse_document_service_provider)
          # TODO: create client from lighthouse document service
        else
          client = EVSS::DocumentsService.new(auth_headers)
        end
        file_body = File.open(pdf_path).read
        client.upload(file_body, document_data)
      ensure
        # Delete the temporary PDF file
        File.delete(pdf_path) if pdf_path.present?
      end
    end
  end
end
