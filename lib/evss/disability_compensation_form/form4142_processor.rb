# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # A {Form4142Processor} handles the work of generating a stamped PDF
    # and a request body for a 4142 CentralMail submission
    #
    class Form4142Processor
      # @return [Pathname] the generated PDF path
      attr_reader :pdf_path

      # @return [Hash] the generated request body
      attr_reader :request_body

      FORM_ID = '21-4142'
      FOREIGN_POSTALCODE = '00000'

      # @param submission [Form526Submission] a user's post-translated 526 submission
      # @param jid [String] the Sidekiq job id for the job submitting the 4142 form
      #
      # @return [EVSS::DisabilityCompensationForm::Form4142Processor] an instance of this class
      #
      def initialize(submission, jid)
        @submission = submission
        @pdf_path = generate_stamp_pdf
        @request_body = {
          'document' => to_faraday_upload,
          'metadata' => generate_metadata(jid)
        }
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method CentralMail::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "FDC Reviewed - Vets.gov Submission" at the top of each page
      #
      # @return [Pathname] the stamped PDF path
      #
      def generate_stamp_pdf
        pdf = PdfFill::Filler.fill_ancillary_form(
          @submission.form[Form526Submission::FORM_4142], @submission.submitted_claim_id, FORM_ID
        )
        stamped_path = CentralMail::DatestampPdf.new(pdf).run(text: 'VA.gov', x: 5, y: 5)
        CentralMail::DatestampPdf.new(stamped_path).run(
          text: 'VA.gov Submission',
          x: 510,
          y: 775,
          text_only: true
        )
      end

      private

      def to_faraday_upload
        Faraday::UploadIO.new(
          @pdf_path,
          Mime[:pdf].to_s
        )
      end

      def generate_metadata(jid)
        form = @submission.form[Form526Submission::FORM_4142]
        veteran_full_name = form['veteranFullName']
        address = form['veteranAddress']

        {
          'veteranFirstName' => veteran_full_name['first'],
          'veteranLastName' => veteran_full_name['last'],
          'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          'receiveDt' => received_date,
          'uuid' => jid,
          'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
          'source' => 'VA Forms Group B',
          'hashV' => Digest::SHA256.file(@pdf_path).hexdigest,
          'numberAttachments' => 0,
          'docType' => FORM_ID,
          'numberPages' => PDF::Reader.new(@pdf_path).pages.size
        }.to_json
      end

      def received_date
        date = SavedClaim::DisabilityCompensation.find(@submission.saved_claim_id).created_at
        date = date.in_time_zone('Central Time (US & Canada)')
        date.strftime('%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
