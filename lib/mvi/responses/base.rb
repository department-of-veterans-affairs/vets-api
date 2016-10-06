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

      def initialize(response)
        @original_body = response.body[:prpa_in201306_uv02]
        @code = @original_body[:acknowledgement][:type_code][:@code]
        @original_reponse = response.xml
      end

      def invalid?
        @code == RESPONSE_CODES[:invalid_request]
      end

      def failure?
        @code == RESPONSE_CODES[:failure]
      end

      def record_not_found?
        @code == RESPONSE_CODES[:record_not_found]
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
