# frozen_string_literal: true
module Common
  module Exceptions
    # Invalid Pagination Params - if page or per_page params are invalid
    class InvalidPaginationParams < BaseError
      attr_reader :pagination_params

      def initialize(pagination_params, options = {})
        @pagination_params = pagination_params
        @detail = options[:detail]
      end

      def errors
        detail = @detail || "#{pagination_params} are invalid"
        Array(SerializableError.new(MinorCodes::INVALID_PAGINATION_PARAMS.merge(detail: detail)))
      end
    end
  end
end
