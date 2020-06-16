# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # Parameter Missing - required parameter was not provided
    class ParameterMissing < Common::Exceptions::BaseError
      attr_reader :param

      def initialize(param, options = {})
        @param = param
        @detail = options[:detail] || i18n_field(:detail, param: @param)
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
