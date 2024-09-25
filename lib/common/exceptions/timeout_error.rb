# frozen_string_literal: true

require 'common/exceptions/base_error'

module Common
  module Exceptions
    class Timeout < BaseError
      def errors
        Array(SerializableError.new(i18n_data))
      end
    end
  end
end
