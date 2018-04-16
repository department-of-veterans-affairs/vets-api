# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module IntentToFile
    class ServiceException < EVSS::ServiceException
      ERROR_MAP = {
        'partner.service.error' => 'evss.intent_to_file.partner_service_error',
        'service.error' => 'evss.intent_to_file.internal_service_error',
        'intentType.invalid' => 'evss.intent_to_file.intent_type_invalid',
        'partner.service.invalid' => 'evss.intent_to_file.partner_service_invalid',
        'default' => 'common.exceptions.internal_server_error'
      }.freeze

      attr_reader :key, :messages
    end
  end
end
