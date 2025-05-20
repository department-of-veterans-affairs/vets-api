# frozen_string_literal: true

require 'pdf_fill/filler'
require 'pdf_utilities/datestamp_pdf'
require 'decision_review_v1/utilities/constants'
require 'simple_forms_api_submission/metadata_validator'

module DecisionReviewV1
  module Processor
    class Form4142ValidationError < StandardError
      def initialize(errors)
        super
        @errors = errors
      end
    end

    class Form4142Processor
      SIGNATURE_DATE_KEY = 'signatureDate'
      SIGNATURE_TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S'
      TIMEZONE = 'Central Time (US & Canada)'
      # @return [Pathname] the generated PDF path
      attr_reader :pdf_path

      # @return [Hash] the generated request body
      attr_reader :request_body

      def initialize(form_data:, submission_id: nil)
        @submission = Form526Submission.find_by(id: submission_id)
        @form = set_signature_date(form_data)
        validate_form4142
        @pdf_path = generate_stamp_pdf
        @request_body = {
          'document' => to_faraday_upload,
          'metadata' => generate_metadata
        }
      end

      def uuid
        @uuid ||= SecureRandom.uuid
      end

      def generate_stamp_pdf
        pdf = PdfFill::Filler.fill_ancillary_form(@form, uuid, FORM_ID)

        # Signature form field can't be populated using pdftk fill_form, so we need to generate a stamp.
        signature_stamped_path = PDFUtilities::DatestampPdf.new(pdf).run(
          text: signature,
          x: 50,
          y: 560,
          text_only: true,
          size: 10,
          page_number: 1,
          template: pdf,
          multistamp: true,
          timestamp_required: false
        )

        stamped_path = PDFUtilities::DatestampPdf.new(signature_stamped_path).run(
          text: 'VA.gov',
          x: 5,
          y: 5,
          timestamp: submission_date
        )

        stamped_path = PDFUtilities::DatestampPdf.new(stamped_path).run(
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

      def generate_metadata
        address = @form['veteranAddress']
        country_is_us = address['country'] == 'US'
        veteran_full_name = @form['veteranFullName']
        metadata = {
          'veteranFirstName' => veteran_full_name['first'],
          'veteranLastName' => veteran_full_name['last'],
          'fileNumber' => @form['vaFileNumber'] || @form['veteranSocialSecurityNumber'],
          'receiveDt' => received_date,
          # 'uuid' => "#{@uuid}_4142", # was trying to include the main claim uuid here and just append 4142
          # but central mail portal does not support that
          'uuid' => uuid,
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
        if @submission.nil?
          Time.now.in_time_zone(TIMEZONE)
        else
          @submission.created_at.in_time_zone(TIMEZONE)
        end
      end

      def received_date
        submission_date.strftime(SIGNATURE_TIMESTAMP_FORMAT)
      end

      def signature
        return unless @form['signatureDate'].present?

        full_name = @form.dig('veteranFullName')
        [full_name['first'], full_name['middle'], full_name['last']].compact.join(' ')
      end

      def set_signature_date(incoming_data)
        incoming_data.merge({ SIGNATURE_DATE_KEY => received_date })
      end

      def validate_form4142
        return unless Flipper.enabled?(:form4142_validate_schema)

        schema = VetsJsonSchema::SCHEMAS[FORM_ID]
        errors = JSON::Validator.fully_validate(schema, @form, errors_as_objects: true)

        unless errors.empty?
          Rails.logger.error('Form 4142 failed validation', { errors: })
          raise Form4142ValidationError.new({ errors: })
        end
      end
    end
  end
end
