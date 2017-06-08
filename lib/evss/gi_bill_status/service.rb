# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def get_stuff
        raw_response = get ''
        puts raw_response.inspect
      end
    end
  end
end
