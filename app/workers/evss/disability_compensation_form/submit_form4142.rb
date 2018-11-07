# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm4142 < Job
      FORM_ID = '21-4142'
      FOREIGN_POSTALCODE = '00000'
      STATSD_KEY_PREFIX = 'worker.evss.submit_form4142'

      class CentralMailResponseError < Common::Exceptions::BackendServiceException
      end

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      sidekiq_retries_exhausted do |msg, _ex|
        log_message_to_sentry(
          "Failed all retries on Form4142 submit, last error: #{msg['error_message']}",
          :error
        )
      end

      # Performs an asynchronous job for submitting a Form 4142 to central mail service
      #
      # @param submission_id [Hash] The submission record
      #
      def perform(submission_id)
        super(submission_id)
        with_tracking('Form4142 Submission') do
          pdf_path = generate_stamp_pdf
          response = CentralMail::Service.new.upload({
            'metadata' => generate_metadata(pdf_path).to_json,
            'document' => to_faraday_upload(pdf_path)
          })
          handle_service_exception(response) if response.present? && response.status.between?(201, 600)
        end
      rescue StandardError => error
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(error)
        raise error
      ensure
        # Delete the temporary PDF file
        File.delete(pdf_path) if pdf_path.present?
      end

      private

      def to_faraday_upload(file_path)
        Faraday::UploadIO.new(
          file_path,
          Mime[:pdf].to_s
        )
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method CentralMail::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VETS.GOV" at the bottom of each page
      # and second time to stamp with text "FDC Reviewed - Vets.gov Submission" at the top of each page
      def generate_stamp_pdf
        pdf_path = PdfFill::Filler.fill_ancillary_form(form[FORM_4142], submitted_claim_id, FORM_ID)
        stamped_path1 = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
        CentralMail::DatestampPdf.new(stamped_path1).run(
          text: 'FDC Reviewed - Vets.gov Submission',
          x: 429,
          y: 770,
          text_only: true
        )
      end

      def get_hash_and_pages(file_path)
        {
          hash: Digest::SHA256.file(file_path).hexdigest,
          pages: PDF::Reader.new(file_path).pages.size
        }
      end

      def generate_metadata(pdf_path)
        form_pdf_metadata = get_hash_and_pages(pdf_path)
        veteran_full_name = form['veteranFullName']
        address = form['veteranAddress']

        {
          'veteranFirstName' => veteran_full_name['first'],
          'veteranLastName' => veteran_full_name['last'],
          'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          'receiveDt' => format_saved_claim_created_at(saved_claim_created_at).strftime('%Y-%m-%d %H:%M:%S'),
          'uuid' => jid,
          'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
          'source' => 'VA Forms Group B',
          'hashV' => form_pdf_metadata[:hash],
          'numberAttachments' => 0,
          'docType' => FORM_ID,
          'numberPages' => form_pdf_metadata[:pages]
        }
      end

      def format_saved_claim_created_at
        return Time.now.in_time_zone('Central Time (US & Canada)') if saved_claim_created_at.blank?
        formatted_created_at = Date.parse(saved_claim_created_at) if saved_claim_created_at.is_a?(String)
        formatted_created_at.in_time_zone('Central Time (US & Canada)')
      end

      # Cannot move job straight to dead queue dynamically within an executing job
      # raising error for all the exceptions as sidekiq will then move into dead queue
      # after all retries are exhausted
      def handle_service_exception(response)
        # create service error with CentralMailResponseError
        error = create_service_error(nil, self.class, response)
        raise error
      end

      def create_service_error(key, source, response, _error = nil)
        response_values = response_values(key, source, response.status, response.body)
        CentralMailResponseError.new(key, response_values, nil, nil)
      end

      def response_values(key, source, status, detail)
        {
          status: status,
          detail: detail,
          code: key,
          source: source.to_s
        }
      end

      def saved_claim_created_at
        @saved_claim_created_at ||= submission.saved_claim.created_at
      end
    end
  end
end
