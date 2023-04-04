# frozen_string_literal: true

require 'decision_review_v1/utilities/constants'

module DecisionReviewV1
  module Processor
    class Form4142Processor
      # @return [Pathname] the generated PDF path
      attr_reader :pdf_path

      # @return [Hash] the generated request body
      attr_reader :request_body

      def initialize(form_data:, response:)
        @form = form_data
        @response = response
        @pdf_path = generate_stamp_pdf
        @uuid = @response.is_a?(Hash) ? @response['data']['id'] : @response.body['data']['id']
        @request_body = {
          'document' => to_faraday_upload,
          'metadata' => generate_metadata
        }
      end

      def generate_stamp_pdf
        pdf = PdfFill::Filler.fill_ancillary_form(
          @form, @uuid, FORM_ID
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

      def generate_metadata
        veteran_full_name = @form['veteranFullName']
        address = @form['veteranAddress']
        {
          'veteranFirstName' => veteran_full_name['first'],
          'veteranLastName' => veteran_full_name['last'],
          'fileNumber' => @form['vaFileNumber'] || @form['veteranSocialSecurityNumber'],
          'receiveDt' => received_date,
          # 'uuid' => "#{@uuid}_4142", # was trying to include the main claim uuid here and just append 4142
          # but central mail portal does not support that
          'uuid' => SecureRandom.uuid,
          'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
          'source' => 'VA Forms Group B',
          'hashV' => Digest::SHA256.file(@pdf_path).hexdigest,
          'numberAttachments' => 0,
          'docType' => FORM_ID,
          'numberPages' => PDF::Reader.new(@pdf_path).pages.size
        }.to_json
      end

      def received_date
        date = Time.now.in_time_zone('Central Time (US & Canada)')
        date.strftime('%Y-%m-%d %H:%M:%S')
      end
    end
  end
end
