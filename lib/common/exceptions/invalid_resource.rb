# frozen_string_literal: true
module Common
  module Exceptions
    # Invalid Resource - if a requested route does not exist
    class InvalidResource < BaseError
      attr_reader :resource

      def initialize(resource, options = {})
        @resource = resource
        @detail = options[:detail]
      end

      def errors
        detail = @detail || "#{resource} is not a valid resource"
        Array(SerializableError.new(MinorCodes::INVALID_RESOURCE.merge(detail: detail)))
      end
    end
  end
end
