# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    class FailedDependency < BaseError
      def initialize(detail: nil)
        @detail = detail
        super
      end

      def errors
        data = @detail.present? ? i18n_data.merge(detail: @detail) : i18n_data
        Array(SerializableError.new(data))
      end
    end
  end
end
