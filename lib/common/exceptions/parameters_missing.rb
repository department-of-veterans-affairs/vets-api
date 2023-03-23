# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

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
          detail = i18n_field(:detail, param:)
          SerializableError.new(i18n_data.merge(detail:))
        end
      end
    end
  end
end
