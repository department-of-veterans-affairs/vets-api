# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    # Invalid Resource - if a requested route does not exist
    class InvalidResource < Common::Exceptions::BaseError
      attr_reader :resource

      def initialize(resource, options = {})
        @resource = resource
        @detail = options[:detail] || i18n_field(:detail, resource: @resource)
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
