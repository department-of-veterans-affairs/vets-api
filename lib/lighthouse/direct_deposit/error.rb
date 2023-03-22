# frozen_string_literal: true

require_relative 'base'

module Lighthouse
  module DirectDeposit
    class Error < Base
      attribute :status, String
      attribute :title, String
      attribute :detail, String
      attribute :instance, String
      attribute :meta, Array

      # Converts a decoded JSON response from Lighthouse to an instance of the Error model
      # @param body [Hash] the decoded response body from Lighthouse
      # @return [Lighthouse::DirectDeposit::Error] the model built from the response body
      def self.build_from(status, body)
        Lighthouse::DirectDeposit::Error.new(
          status: body['status'],
          title: parse_title(status, body),
          detail: parse_detail(body),
          instance: body['instance'],
          meta: map_error_codes(body['errorCodes'])
        )
      end

      def self.parse_title(status, body)
        return body['title'] if body['title']
        return body['error'] if body['error']

        status_message_from(status)
      end

      def self.parse_detail(body)
        return body['detail'] if body['detail']
        return body['error_description'] if body['error_description']

        body['message']
      end

      def self.map_error_codes(errors)
        errors&.map do |e|
          { key: e['errorCode'], text: e['detail'] }
        end
      end

      def self.status_message_from(code)
        case code
        when 401
          'Not Authorized'
        when 403
          'Forbidden'
        when 413
          'Payload too large'
        when 429
          'Too many requests'
        end
      end
    end
  end
end
