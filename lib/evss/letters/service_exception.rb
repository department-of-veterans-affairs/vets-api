# frozen_string_literal: true

require 'evss/service_exception'

module EVSS
  module Letters
    class ServiceException < EVSS::ServiceException
      ERROR_MAP = {
        serviceError: 'evss.external_service_unavailable',
        notEligible: 'evss.letters.not_eligible',
        letterEligibilityError: 'evss.letters.unable_to_determine_eligibilty',
        letterDestination: 'evss.letters.unprocessable_entity',
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
