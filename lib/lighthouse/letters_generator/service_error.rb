# frozen_string_literal: true

require 'common/exceptions/base_error'

module Lighthouse
  module LettersGenerator
    class ServiceError < Common::Exceptions::BaseError
      attr_accessor :title, :status, :message, :key

      ERROR_MAP = {
        400 => 'lighthouse.letters_generator.bad_request',
        401 => 'lighthouse.letters_generator.not_authorized',
        403 => 'lighthouse.letters_generator.forbidden',
        404 => 'lighthouse.letters_generator.not_found',
        406 => 'lighthouse.letters_generator.not_acceptable',
        413 => 'lighthouse.letters_generator.payload_too_large',
        422 => 'lighthouse.letters_generator.unprocessable_entity',
        429 => 'lighthouse.letters_generator.too_many_requests',
        504 => 'lighthouse.letters_generator.gateway_timeout',
        default: 'common.exceptions.internal_server_error'
      }.freeze

      # Expects a response in one of these formats:
      #  { status: "", title: "", detail: "", type: "", instance: "" }
      # OR
      #  { message: "" }
      # @exception Exception [Faraday::ClientError|Faraday::ServerErrror] the exception returned by Faraday middleware
      def initialize(exception = nil)
        super
        unless exception.nil?
          @status ||= exception['status'].to_i
          @title ||= exception['title']
          @message = exception['detail'] || exception['message']
        end
        @key ||= error_key
      end

      def errors
        Array(
          Common::Exceptions::SerializableError.new(
            i18n_data.merge(title: @title, meta: { message: @message }, source: 'Lighthouse::LettersGenerator::Service')
          )
        )
      end

      private

      def i18n_key
        @key
      end

      def error_key
        ERROR_MAP[@status] || ERROR_MAP[:default]
      end
    end
  end
end
