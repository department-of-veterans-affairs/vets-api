# frozen_string_literal: true

module Common
  module Exceptions
    class ServiceError < BaseError
      attr_writer :source

      def initialize(options = {})
        @detail = options[:detail]
        @source = options[:source]
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail, source: @source)))
      end
    end
  end
end
