# frozen_string_literal: true

require 'evss/service_exception'

module EVSS
  module PPIU
    class ServiceException < EVSS::ServiceException
      ERROR_MAP = {
        exception: 'evss.external_service_unavailable',
        cnp: 'evss.ppiu.unprocessable_entity',
        indicators: 'evss.ppiu.unprocessable_entity',
        modelvalidators: 'evss.ppiu.unprocessable_entity',
        default: 'common.exceptions.internal_server_error'
      }.freeze

      def errors
        Array(
          Common::Exceptions::SerializableError.new(
            i18n_data.merge(source: 'EVSS::Letters::Service', meta: { messages: @messages })
          )
        )
      end

      private

      def i18n_key
        @key
      end
    end
  end
end
