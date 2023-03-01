# frozen_string_literal: true

require_relative 'base'

module Lighthouse
  module DirectDeposit
    class Error < Base
      attribute :status, String
      attribute :message, String
      attribute :detail, String
      attribute :reference, String

      # Converts a decoded JSON response from Lighthouse to an instance of the Error model
      # @param body [Hash] the decoded response body from Lighthouse
      # @return [Lighthouse::DirectDeposit::Error] the model built from the response body
      def self.build_from(status, body)
        case status
        when 400, 404, 500, 502
          # 400 (Bad Request), 404 (Not Found), 500 (Internal Server Error), 502 (Bad Gateway)
          Lighthouse::DirectDeposit::Error.new(
            status: body['status'],
            message: body['title'],
            detail: body['detail'],
            reference: body['instance']
          )
        when 401, 403, 413, 429
          # 401 (Not Authorized), 403 (Forbidden), 413 (Payload too large), 429 (Too many requests)
          Lighthouse::DirectDeposit::Error.new(
            status: status,
            message: status_message_from(status),
            detail: body['message']
          )
        else
          Lighthouse::DirectDeposit::Error.new(status: status, message: 'Unknown', detail: 'Unknown Error')
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
