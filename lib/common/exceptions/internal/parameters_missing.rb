# frozen_string_literal: true

module Common
  module Exceptions
    # Parameter Missing - required parameter was not provided
    class ParametersMissing < BaseError
      attr_reader :params

      def initialize(params)
        @params = params
      end

      def errors
        @params.map do |param|
          detail = i18n_field(:detail, param: param)
          SerializableError.new(i18n_data.merge(detail: detail))
        end
      end
    end
  end
end
