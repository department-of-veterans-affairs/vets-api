# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  class ServiceException < Common::Exceptions::BaseError
    attr_reader :key, :messages

    def initialize(original_body)
      @messages = original_body['messages']
      @key = error_key
      super
    end

    private

    def error_key
      # in case of multiple errors highest priority code is the one set for the http response
      key = self.class::ERROR_MAP.select { |k, _v| messages_has_key?(k) }
      return key.values.first unless key.empty?
      self.class::ERROR_MAP[:default]
    end

    def messages_has_key?(key)
      @messages.any? { |m| m['key'].include? key.to_s }
    end
  end
end
