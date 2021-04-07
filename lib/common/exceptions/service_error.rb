# frozen_string_literal: true

require 'common/exceptions/base_error'

module Common
  module Exceptions
    class ServiceError < BaseError
      attr_writer :source

      def initialize(options = {})
        @detail = options[:detail]
        @source = options[:source]
        @errors = options[:errors]
      end

      def errors
        return @errors if @errors.present?

        Array(SerializableError.new(i18n_data.merge(detail: @detail, source: @source)))
      end
    end
  end
end
