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

      CODE_XPATH = 'acknowledgement/typeCode/@code'
      QUERY_XPATH = 'controlActProcess/queryByParameter'

      class << self
        attr_accessor :endpoint
      end

      def self.mvi_endpoint(endpoint)
        @endpoint = endpoint
      end
      delegate :endpoint, to: 'self.class'

      def initialize(response)
        @original_response = response.body
        @original_body = locate_element(Ox.parse(@original_response), "env:Body/idm:#{endpoint.to_s}")
        @code = locate_element(@original_body, CODE_XPATH)
        @query = locate_element(@original_body, QUERY_XPATH)
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

      private

      def locate_element(el, path)
        el.locate(path).first
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
