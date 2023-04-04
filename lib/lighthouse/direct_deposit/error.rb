# frozen_string_literal: true

require_relative 'base'
require 'lighthouse/direct_deposit/parsers/bad_request_parser'
require 'lighthouse/direct_deposit/parsers/denied_request_parser'
require 'lighthouse/direct_deposit/parsers/invalid_creds_parser'

module Lighthouse
  module DirectDeposit
    class Error < StandardError
      attr_accessor :status
      attr_writer :body

      def initialize(response)
        @status = response.status
        @body = parse_body(response)
        super
      end

      def title
        @body['title']
      end

      def body
        {
          errors: [@body]
        }
      end

      def parse_body(response)
        parser =
          if request_denied?(response.body)
            Lighthouse::DirectDeposit::Parsers::DeniedRequestParser.new(response)
          elsif invalid_creds?(response.body)
            Lighthouse::DirectDeposit::Parsers::InvalidCredsParser.new(response)
          else
            Lighthouse::DirectDeposit::Parsers::BadRequestParser.new(response)
          end

        parser.parse_body
      end

      def ok?
        false
      end

      private

      def request_denied?(body)
        body['message']&.present?
      end

      def invalid_creds?(body)
        body['error']&.present?
      end
    end
  end
end
