# frozen_string_literal: true

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
