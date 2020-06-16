# frozen_string_literal: true

module Common
  module Exceptions::Internal
    class SchemaValidationErrors < Common::Exceptions::BaseError
      def initialize(resource)
        @resource = resource
        raise TypeError, 'the resource provided has no errors' if resource.blank?
      end

      def errors
        @resource.map do |error|
          Common::Exceptions::SerializableError.new(
            i18n_data.merge(
              detail: error
            )
          )
        end
      end
    end
  end
end
