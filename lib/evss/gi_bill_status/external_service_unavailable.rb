# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module GiBillStatus
    class ExternalServiceUnavailable < Common::Exceptions::BaseError
      def initialize
        super
      end

      def errors
        [Common::Exceptions::SerializableError.new(i18n_data)]
      end

      def i18n_key
        'evss.external_service_unavailable'
      end
    end
  end
end
