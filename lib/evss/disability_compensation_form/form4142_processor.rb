# frozen_string_literal: true

require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_utilities/datestamp_pdf'
require 'simple_forms_api_submission/metadata_validator'

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
      # Then calls method PDFUtilities::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "FDC Reviewed - Vets.gov Submission" at the top of each page
      #
      # @return [Pathname] the stamped PDF path
      #
      def generate_stamp_pdf
        pdf = PdfFill::Filler.fill_ancillary_form(
          form4142, @submission.submitted_claim_id, FORM_ID
        )
        stamped_path = PDFUtilities::DatestampPdf.new(pdf).run(text: 'VA.gov', x: 5, y: 5,
                                                               timestamp: submission_date)
        PDFUtilities::DatestampPdf.new(stamped_path).run(
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
        address = form4142['veteranAddress']
        country_is_us = address['country'] == 'USA'
        veteran_full_name = form4142['veteranFullName']
        metadata = {
          'veteranFirstName' => veteran_full_name['first'],
          'veteranLastName' => veteran_full_name['last'],
          'fileNumber' => form4142['vaFileNumber'] || form4142['veteranSocialSecurityNumber'],
          'receiveDt' => received_date,
          'uuid' => jid,
          'zipCode' => address['postalCode'],
          'source' => 'VA Forms Group B',
          'hashV' => Digest::SHA256.file(@pdf_path).hexdigest,
          'numberAttachments' => 0,
          'docType' => FORM_ID,
          'numberPages' => PDF::Reader.new(@pdf_path).pages.size
        }

        SimpleFormsApiSubmission::MetadataValidator.validate(
          metadata, zip_code_is_us_based: country_is_us
        ).to_json
      end

      def submission_date
        @submission.created_at.in_time_zone('Central Time (US & Canada)')
      end

      def received_date
        submission_date.strftime('%Y-%m-%d %H:%M:%S')
      end

      def form4142
        @form4142 ||= set_signature_date(@submission.form[Form526Submission::FORM_4142])
      end

      def set_signature_date(incoming_data)
        incoming_data.merge({ 'signatureDate' => received_date })
      end
    end
  end
end
