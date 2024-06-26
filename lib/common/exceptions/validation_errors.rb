# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Validation Error - an ActiveModel having validation errors, can be sent to this exception
    class ValidationErrors < BaseError
      attr_reader :resource

      def initialize(resource)
        @resource = resource
        raise TypeError, 'the resource provided has no errors' if resource.errors.empty?
      end

      def errors
        @resource.errors.map do |error|
          full_message = error.full_message
          attributes = error_attributes(error.attribute, error.message, full_message)
          SerializableError.new(attributes)
        end
      end

      private

      def error_attributes(key, message, full_message)
        i18n_data.merge(
          title: full_message,
          detail: "#{key.to_s.underscore.dasherize} - #{message}",
          source: { pointer: "data/attributes/#{key.to_s.underscore.dasherize}" }
        )
      end
    end
  end
end
