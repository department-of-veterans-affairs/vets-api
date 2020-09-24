# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Ambiguous Request - the parameters passed in could not determine what query to call
    class AmbiguousRequest < BaseError
      def initialize(detail)
        @detail = detail
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
