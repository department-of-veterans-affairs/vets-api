# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module Letters
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-lettergenerator-services-web/rest/letters/v1"

      def get_letters
        raw_response = get ''
        EVSS::Letters::LettersResponse.new(raw_response)
      end

      def get_letter_for_user_by_type(type)
        get type
      end

      def self.breakers_service
        BaseService.create_breakers_service(name: 'EVSS/Letters', url: BASE_URL)
      end
    end
  end
end
