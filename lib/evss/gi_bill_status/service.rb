# frozen_string_literal: true
require 'evss/base_service'

# :nocov:
module EVSS
  module GiBillStatus
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def get_gi_bill_status
        raw_response = get ''
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response)
        # TODO: error handling and specs
      end
    end
  end
end
# :nocov:
