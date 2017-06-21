# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module GiBillStatus
    class GiBillStatusResponse < EVSS::Response
      attribute :body, EVSS::GiBillStatus::Post911GIBillStatus

      def parse_body(body)
        self.body = body['chapter33_education_info']
      end
    end
  end
end
