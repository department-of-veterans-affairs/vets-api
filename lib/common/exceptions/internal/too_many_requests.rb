# frozen_string_literal: true

module Common
  module Exceptions
    class TooManyRequests < BaseError
      def errors
        Array(SerializableError.new(i18n_interpolated))
      end
    end
  end
end
