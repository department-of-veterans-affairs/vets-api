# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    class TooManyRequests < BaseError
      def errors
        Array(SerializableError.new(i18n_interpolated))
      end

      def i18n_key
        'common.exceptions.too_many_requests'
      end
    end
  end
end
