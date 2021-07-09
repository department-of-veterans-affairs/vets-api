# frozen_string_literal: true

require 'appeals_api/higher_level_review/phone'

module AppealsApi
  module HigherLevelReviews
    class PdfFormFieldValidation
      def initialize(request_body, request_headers, version_validator:)
        @request_body = request_body
        @request_headers = request_headers
        @version_validator = version_validator.new(request_body, request_headers)
      end

      def validate!
        return error(422, veteran_phone.too_long_error_message) if veteran_phone.too_long?

        valid, version_error = version_validator.validate!

        return error(422, version_error) unless valid
      end

      private

      attr_accessor :request_body, :request_headers, :version_validator

      def veteran_phone
        @veteran_phone ||= AppealsApi::HigherLevelReview::Phone.new(phone_data)
      end

      def phone_data
        request_body.dig('data', 'attributes', 'veteran', 'phone')
      end

      def error(status, message)
        [
          status,
          {
            errors: [
              {
                status: 422,
                detail: message
              }
            ]
          }
        ]
      end
    end
  end
end
