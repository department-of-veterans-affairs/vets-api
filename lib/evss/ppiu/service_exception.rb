# frozen_string_literal: true

require 'evss/logged_service_exception'

module EVSS
  module PPIU

    # TODO - see if we can remove
    class ServiceException < EVSS::LoggedServiceException
      ERROR_MAP = {
        fraud: 'evss.ppiu.potential_fraud',
        flashes: 'evss.ppiu.account_flagged',
        exception: 'evss.external_service_unavailable',
        service: 'evss.external_service_unavailable',
        cnp: 'evss.ppiu.unprocessable_entity',
        indicators: 'evss.ppiu.unprocessable_entity',
        modelvalidators: 'evss.ppiu.unprocessable_entity',
        default: 'common.exceptions.internal_server_error'
      }.freeze

      def errors
        Array(
          Common::Exceptions::SerializableError.new(
            i18n_data.merge(source: 'EVSS::PPIU::Service', meta: { messages: @messages })
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
