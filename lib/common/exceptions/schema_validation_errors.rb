# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    class SchemaValidationErrors < BaseError
      def initialize(resource)
        @resource = resource
        raise TypeError, 'the resource provided has no errors' if resource.blank?
      end

      def errors
        @resource.map do |error|
          SerializableError.new(
            i18n_data.merge(
              detail: error
            )
          )
        end
      end
    end
  end
end
