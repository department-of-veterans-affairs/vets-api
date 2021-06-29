# frozen_string_literal: true

require 'appeals_api/higher_level_review/phone'

module AppealsApi
  module HigherLevelReviews
    class PdfFormatValidation
      def initialize(request_body, request_headers, version_validator:)
        @request_body = request_body
        @request_headers = request_headers
        @version_validator = version_validator.new(request_body, request_headers)
      end

      def validate!
        return error(422, phone_length_error) if veteran_phone.too_long?
      end

      private

      attr_accessor :request_body, :request_headers, :version_validator

      def veteran_phone
        @veteran_phone ||= AppealsApi::HigherLevelReview::Phone.new(phone_data)
      end

      def phone_data
        request_body.dig('data', 'attributes', 'veteran', 'phone')
      end

      def phone_length_error
        {
          errors: [
            {
              status: 422,
              detail: veteran_phone.too_long_error_message
            }
          ]
        }
      end

      def error(status, error)
        [
          status,
          error
        ]
      end
    end
  end
end
