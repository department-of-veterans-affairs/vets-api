# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module GiBillStatus
    ##
    # Custom error for when the upstream service is unavailable
    #
    class ExternalServiceUnavailable < Common::Exceptions::BaseError
      ##
      # @return [Array[Common::Exceptions::SerializableError]] An array containing the error
      #
      def errors
        [Common::Exceptions::SerializableError.new(i18n_data)]
      end

      ##
      # @return [String] The i18n key
      #
      def i18n_key
        'evss.external_service_unavailable'
      end
    end
  end
end
