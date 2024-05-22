# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  class ServiceException < Common::Exceptions::BaseError
    attr_reader :key, :messages

    def initialize(original_body)
      @messages = original_body['messages']
      @key = error_key || 'evss.unmapped_service_exception'
      super
    end

    private

    def error_key
      # in case of multiple errors, the ordering of ERROR_MAP is used to decide which error is highest priority.
      # NOTE: The ordering of ERROR_MAP takes precedence over both 1) how the error messages were ordered in the
      # EVSS response and 2) the "severity" keys of those messages.
      error_map = self.class::ERROR_MAP.select { |k, _v| messages_has_key?(k) }
      return error_map.values.first unless error_map.empty?

      self.class::ERROR_MAP[:default]
    end

    def messages_has_key?(key)
      @messages.any? { |m| m['key'].include? key.to_s }
    end
  end
end
