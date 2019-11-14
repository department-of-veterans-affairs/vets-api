# frozen_string_literal: true

module Common
  module Exceptions
    class GatewayTimeout < BaseError
      alias_method :status, :status_code
      
      def errors
        Array(SerializableError.new(i18n_data))
      end
    end
  end
end
