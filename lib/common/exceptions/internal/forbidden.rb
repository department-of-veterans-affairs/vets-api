# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # Forbidden - We may eventually want different variations on this with distinct MinorCodes
    class Forbidden < Common::Exceptions::BaseError
      def initialize(options = {})
        @detail = options[:detail]
        @source = options[:source]
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail, source: @source)))
      end
    end
  end
end
