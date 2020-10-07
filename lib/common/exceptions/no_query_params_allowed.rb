# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    class NoQueryParamsAllowed < BaseError
      def errors
        Array(SerializableError.new(i18n_interpolated))
      end
    end
  end
end
