# frozen_string_literal: true
module Common
  module Exceptions
    # Invalid Pagination Params - if page or per_page params are invalid
    class InvalidPaginationParams < BaseError
      attr_reader :pagination_params

      def initialize(pagination_params, options = {})
        @pagination_params = pagination_params
        @detail = options[:detail] || i18n_field(:detail, params: @pagination_params)
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
