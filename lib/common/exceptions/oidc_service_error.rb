# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    class OpenIdServiceError < BaseError
      attr_reader :detail

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
