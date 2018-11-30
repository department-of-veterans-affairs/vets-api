# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm8940
      include Sidekiq::Worker
      include JobStatus

      FORM_ID = '21-8940' # form id for PTSD IU
      DOC_TYPE = 'L149'

      STATSD_KEY_PREFIX = 'worker.evss.submit_form8940'

      # Sidekiq has built in exponential back-off functionality for retrys
      # A max retry attempt of 10 will result in a run time of ~8 hours
      # This job is invoked from 526 background job
      RETRY = 10

      sidekiq_options retry: RETRY

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        Rails.logger.send(
          :error,
          "Failed all retries on SubmitForm8940 submit, last error: #{msg['error_message']}"
        )
        Metrics.new(STATSD_KEY_PREFIX, msg['jid']).increment_exhausted
      end

      # Performs an asynchronous job for generating and submitting 8940 PDF documents to VBMS
      #
      # @param auth_headers [Hash] The VAAFI headers for the user
      # @param evss_claim_id [String] EVSS Claim id received from 526 submission
      # @param saved_claim_id [Integer] Saved Claim id from 526 submission
      # @param submission_id [String] The submission id of 526, uploads, and 4142 data
      # @param form_content [Hash] The form content for 8940 submission
      #
      def perform(auth_headers, evss_claim_id, saved_claim_id, submission_id, form_content)
        with_tracking('Form8940 Submission', saved_claim_id, submission_id) do
          parsed_form = JSON.parse(form_content)
          parsed_form8940 = parse_8940(parsed_form.deep_dup)

          # process 8940
          process_8940(auth_headers, evss_claim_id, parsed_form8940) if parsed_form8940.present?
        end
      rescue StandardError => error
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(error)
        raise error
      end

      private

      def parse_8940(parsed_form)
        return '' if parsed_form['unemployability'].empty?
        parsed_form
      end

      def process_8940(_auth_headers, evss_claim_id, form_content)
        # generate and stamp PDF file
        pdf_path8940 = generate_stamp_pdf(form_content, evss_claim_id) if form_content.present?
        upload_to_vbms(auth_headers, evss_claim_id, pdf_path8940) if pdf_path8940.present?
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method CentralMail::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "VA.gov Submission" at the top of each page
      def generate_stamp_pdf(form_content, evss_claim_id)
        pdf_path = PdfFill::Filler.fill_ancillary_form(form_content, evss_claim_id, FORM_ID)
        stamped_path1 = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VA.gov', x: 5, y: 5)
        CentralMail::DatestampPdf.new(stamped_path1).run(
          text: 'VA.gov Submission',
          x: 510,
          y: 775,
          text_only: true
        )
      end

      def get_evss_claim_metadata(pdf_path)
        pdf_path_split = pdf_path.split('/')
        {
          doc_type: DOC_TYPE,
          file_name: pdf_path_split.last
        }
      end

      def create_document_data(evss_claim_id, upload_data)
        EVSSClaimDocument.new(
          evss_claim_id: evss_claim_id,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: DOC_TYPE
        )
      end

      def upload_to_vbms(auth_headers, evss_claim_id, pdf_path)
        upload_data = get_evss_claim_metadata(pdf_path)
        document_data = create_document_data(evss_claim_id, upload_data)
        client = EVSS::DocumentsService.new(auth_headers)
        file_body = open(pdf_path).read
        client.upload(file_body, document_data)
      ensure
        # Delete the temporary PDF file
        File.delete(pdf_path) if pdf_path.present?
      end
    end
  end
end
