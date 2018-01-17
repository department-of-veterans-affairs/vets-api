# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module Letters
    class ServiceException < Common::Exceptions::BaseError
      ERROR_MAP = {
        serviceError: 'evss.letters.external_service_unavailable',
        notEligible: 'evss.letters.not_eligible',
        letterEligibilityError: 'evss.letters.unable_to_determine_eligibilty',
        letterDestination: 'evss.letters.unprocessable_entity',
        default: 'common.exceptions.internal_server_error'
      }.freeze

      attr_reader :key, :messages

      def initialize(original_body)
        @messages = original_body['messages']
        @key = error_key
        super
      end

      def errors
        Array(
          Common::Exceptions::SerializableError.new(
            i18n_data.merge(source: 'EVSS::Letters::Service', meta: { messages: @messages })
          )
        )
      end

      private

      def error_key
        # in case of multiple errors highest priority code is the one set for the http response
        key = ERROR_MAP.select { |k, _v| messages_has_key?(k) }
        return key.values.first unless key.empty?
        ERROR_MAP[:default]
      end

      def messages_has_key?(key)
        @messages.any? { |m| m['key'].include? key.to_s }
      end

      def i18n_key
        @key
      end
    end
  end
end
