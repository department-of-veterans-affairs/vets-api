# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'evss/response'

module EVSS
  module GiBillStatus
    class GiBillStatusResponse < EVSS::Response
      include Post911GIBillStatus

      def initialize(status, response = nil)
        attributes = response.body['chapter33_education_info']
        super(status, attributes)
      end
    end
  end
end
