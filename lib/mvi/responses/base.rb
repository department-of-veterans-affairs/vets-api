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
        @original_response = ensure_xml_prolog(response.body)
        doc = Ox.parse(@original_response)
        raise MVI::HTTPError.new('MVI internal server error', 500) if doc_includes_error(doc)
        @original_body = locate_element(doc, "env:Envelope/env:Body/idm:#{endpoint}")
        @code = locate_element(@original_body, CODE_XPATH)
        @query = locate_element(@original_body, QUERY_XPATH).to_json
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

      def ensure_xml_prolog(xml)
        xml.prepend('<?xml version="1.0" encoding="UTF-8"?>') unless xml =~ /^<\?xml/
        xml
      end

      def locate_element(el, path)
        return nil unless el
        el.locate(path)&.first
      end

      def doc_includes_error(doc)
        fault_element = doc.locate('env:Envelope/env:Body/env:Fault').first
        return false unless fault_element
        fault_code = fault_element.locate('faultcode').first
        fault_string = fault_element.locate('faultstring').first
        Rails.logger.error "MVI fault code: #{fault_code.nodes.first}" if fault_code
        Rails.logger.error "MVI fault string: #{fault_string.nodes.first}" if fault_string
        true
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
