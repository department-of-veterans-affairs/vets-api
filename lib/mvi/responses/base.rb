# frozen_string_literal: true
module MVI
  module Responses
    class Base
      attr_accessor :code, :query, :original_response

      RESPONSE_CODES = {
        success: 'AA',
        failure: 'AE',
        invalid_request: 'AR'
      }.freeze

      class << self
        attr_accessor :endpoint
      end

      def self.mvi_endpoint(endpoint)
        @endpoint = endpoint
      end
      delegate :endpoint, to: 'self.class'

      def initialize(response)
        @original_body = response.body[endpoint]
        @original_response = response.xml
        @code = @original_body.dig(:acknowledgement, :type_code, :@code)
        @query = @original_body.dig(:control_act_process, :query_by_parameter)
      end

      def invalid?
        @code == RESPONSE_CODES[:invalid_request]
      end

      def failure?
        @code == RESPONSE_CODES[:failure]
      end

      def body
        raise MVI::Responses::NotImplementedError, 'subclass is expected to implement .body'
      end
    end
    class NotImplementedError < StandardError
    end
    class ResponseError < StandardError
    end
    class RecordNotFound < ResponseError
    end
  end
end
