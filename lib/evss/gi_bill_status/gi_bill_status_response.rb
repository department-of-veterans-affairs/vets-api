# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'common/models/base'

module EVSS
  module GiBillStatus
    class GiBillStatusResponse < Common::Base
      include Common::Client::ServiceStatus

      attribute :status, Integer
      attribute :post911_gi_bill_status, Post911GIBillStatus

      def initialize(raw_response)
        self.post911_gi_bill_status = raw_response.body['chapter33_education_info']
        self.status = raw_response.status
      end

      def ok?
        status == 200
      end

      def metadata
        {
          status: ok? ? RESPONSE_STATUS[:ok] : RESPONSE_STATUS[:server_error]
        }
      end
    end
  end
end
