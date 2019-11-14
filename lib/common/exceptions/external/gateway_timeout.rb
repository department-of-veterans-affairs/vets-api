# frozen_string_literal: true

module Common
  module Exceptions
    class GatewayTimeout < BaseError
      def errors
        Array(SerializableError.new(i18n_data))
      end
    end
  end
end
