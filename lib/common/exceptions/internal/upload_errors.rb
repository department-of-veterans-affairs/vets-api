# frozen_string_literal: true
module Common
  module Exceptions
    # Validation Errors on Uploads - a list of messages.
    class UploadErrors < BaseError
      attr_reader :resource

      def initialize(resource)
        @resource = resource
        raise TypeError, 'the resource provided has no errors' if resource.errors.empty?
      end

      def errors
        @resource.errors.map do |e|
          attributes = error_attributes(e.key, e.message, e.message)
          SerializableError.new(attributes)
        end
      end

      def to_s
        @resource.errors.map(&:message).join(', ')
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
