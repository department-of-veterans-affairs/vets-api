# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm0781
      include Sidekiq::Worker
      include JobStatus

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
        log_message_to_sentry(
          "Failed all retries on SubmitForm0781 submit, last error: #{msg['error_message']}",
          :error
        )
      end

      # Performs an asynchronous job for generating and submitting 0781 + 0781A PDF documents to VBMS
      #
      # @param auth_headers [Hash] The VAAFI headers for the user
      # @param evss_claim_id [String] EVSS Claim id received from 526 submission
      # @param saved_claim_id [Integer] Saved Claim id from 526 submission
      # @param submission_id [String] The submission id of 526, uploads, and 4142 data
      # @param form_content [Hash] The form content for 0781 + 0781A submission
      #
      def perform(auth_headers, evss_claim_id, saved_claim_id, submission_id, form_content)
        with_tracking('Form0781 Submission', saved_claim_id, submission_id) do
          @parsed_form = parse_form(form_content)
          @parsed_form0781 = get_form_0781
          @parsed_form0781a = get_form_0781a

          # process 0781 and 0781a
          process_0781(auth_headers, evss_claim_id) if @parsed_form0781.present?
          process_0781a(auth_headers, evss_claim_id) if @parsed_form0781a.present?
        end
      rescue StandardError => error
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(error)
        raise error
      ensure
        # Delete the temporary PDF file
        delete_temp_files
      end

      private

      def parse_form(form_content)
        form_content = form_content.to_json if form_content.is_a?(Hash)

        # Parse form content to JSON
        @parsed_form ||= JSON.parse(form_content)
      end

      def get_form_0781
        @parsed_form0781 = @parsed_form.deep_dup
        @parsed_form0781['incident'].delete_if do |incident|
          true if incident['personalAssault']
        end
        if @parsed_form0781['incident'].empty?
          @parsed_form0781 = ''
        else
          @parsed_form0781.to_json if @parsed_form0781.is_a?(Hash)
          @parsed_form0781 ||= JSON.parse(@parsed_form0781)
        end
      end

      def get_form_0781a
        @parsed_form0781a = @parsed_form.deep_dup
        @parsed_form0781a['incident'].delete_if do |incident|
          true unless incident['personalAssault']
        end
        if @parsed_form0781a['incident'].empty?
          @parsed_form0781a = ''
        else
          @parsed_form0781a.to_json if @parsed_form0781a.is_a?(Hash)
          @parsed_form0781a ||= JSON.parse(@parsed_form0781a)
        end
      end

      def process_0781(auth_headers, evss_claim_id)
        # generate and stamp PDF file
        @pdf_path0781 = generate_stamp_pdf(@parsed_form0781, evss_claim_id, FORM_ID_0781)
        upload_to_vbms(auth_headers, evss_claim_id, @pdf_path0781, FORM_ID_0781) if @pdf_path0781.present?
      end

      def process_0781a(auth_headers, evss_claim_id)
        # generate and stamp PDF file
        @pdf_path0781a = generate_stamp_pdf(@parsed_form0781a, evss_claim_id, FORM_ID_0781A)
        upload_to_vbms(auth_headers, evss_claim_id, @pdf_path0781a, FORM_ID_0781A) if @pdf_path0781a.present?
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method CentralMail::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VETS.GOV" at the bottom of each page
      # and second time to stamp with text "FDC Reviewed - Vets.gov Submission" at the top of each page
      def generate_stamp_pdf(form_content, evss_claim_id, form_id)
        pdf_path = PdfFill::Filler.fill_ancillary_form(form_content, evss_claim_id, form_id)
        stamped_path1 = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
        CentralMail::DatestampPdf.new(stamped_path1).run(
          text: 'FDC Reviewed - Vets.gov Submission',
          x: 429,
          y: 770,
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
          evss_claim_id: evss_claim_id,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: upload_data[:doc_type]
        )
      end

      def upload_to_vbms(auth_headers, evss_claim_id, pdf_path, form_id)
        upload_data = get_evss_claim_metadata(pdf_path, form_id)
        document_data = create_document_data(evss_claim_id, upload_data)
        client = EVSS::DocumentsService.new(auth_headers)
        file_body = open(pdf_path).read
        client.upload(file_body, document_data)
      end

      def delete_temp_files
        File.delete(@pdf_path0781) if @pdf_path0781.present?
        File.delete(@pdf_path0781a) if @pdf_path0781a.present?
      end
    end
  end
end
