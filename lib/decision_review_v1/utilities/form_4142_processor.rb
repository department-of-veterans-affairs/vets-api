# frozen_string_literal: true

require 'pdf_fill/filler'
require 'central_mail/datestamp_pdf'
require 'decision_review_v1/utilities/constants'
require 'simple_forms_api_submission/metadata_validator'

module DecisionReviewV1
  module Processor
    class Form4142ProcessorWipn

      SC_REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze
      SC_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'SC-CREATE-RESPONSE-200_V1'
      SC_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'SC-SHOW-RESPONSE-200_V1'

      FORM4142_ID = '4142'
      FORM_ID = '21-4142'
      SUPP_CLAIM_FORM_ID = '20-0995'

      NOD_REQUIRED_CREATE_HEADERS = %w[X-VA-File-Number X-VA-First-Name X-VA-Last-Name X-VA-Birth-Date].freeze
      NOD_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'NOD-CREATE-RESPONSE-200_V1'
      NOD_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'NOD-SHOW-RESPONSE-200_V1'

      HLR_REQUIRED_CREATE_HEADERS = %w[X-VA-First-Name X-VA-Last-Name X-VA-SSN X-VA-Birth-Date].freeze
      HLR_CREATE_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-CREATE-RESPONSE-200_V1'
      HLR_SHOW_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-SHOW-RESPONSE-200_V1'

      # TODO: rename the imported schema as its shared with Supplemental Claims
      GET_LEGACY_APPEALS_RESPONSE_SCHEMA = VetsJsonSchema::SCHEMAS.fetch 'HLR-GET-LEGACY-APPEALS-RESPONSE-200'

      GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA =
      VetsJsonSchema::SCHEMAS.fetch 'DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1'

      # @return [Pathname] the generated PDF path
      attr_reader :pdf_path

      # @return [Hash] the generated request body
      attr_reader :request_body

      def initialize(form_data:, submission_id: nil)
        @submission = Form526Submission.find_by(id: submission_id)
        @form = add_timestamp(form_data)
        @pdf_path = generate_stamp_pdf
        @uuid = SecureRandom.uuid
        @request_body = {
          'document' => to_faraday_upload,
          'metadata' => generate_metadata
        }
      end

      def add_timestamp(form_data)
        form_data.merge({ signatureDate: timestamp })
      end

      def generate_stamp_pdf
        pdf = PdfFill::Filler.fill_ancillary_form(
          @form, @uuid, FORM_ID
        )
        stamped_path = CentralMail::DatestampPdf.new(pdf).run(text: 'VA.gov', x: 5, y: 5, timestamp: submission_date)

        CentralMail::DatestampPdf.new(stamped_path).run(
          text: 'VA.gov Submission',
          x: 510,
          y: 775,
          text_only: false,
          timestamp: submission_date
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
          'receiveDt' => submission_date, # wipn << not received_date
          # 'uuid' => "#{@uuid}_4142", # was trying to include the main claim uuid here and just append 4142
          # but central mail portal does not support that
          'uuid' => @uuid,
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
        timestamp = @submission.created_at.in_time_zone('Central Time (US & Canada)')
        puts("\n\n wipn8923 :: #{File.basename(__FILE__)}-#{self.class.name}##{__method__.to_s} - \n\t timestamp: #{timestamp} \n\n")
        timestamp
      end

      def received_date
        submission_date.strftime('%Y-%m-%d %H:%M:%S')
      end
    end
  end
end

thing = DecisionReviewV1::Processor::Form4142ProcessorWipn.new(form_data: sub.form['form4142'], submission_id: sub.id)
S3Uploader.new(file_path: thing.pdf_path).run
