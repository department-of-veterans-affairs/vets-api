# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'common/models/base'

module Vye
  module DGIB
    class Response < Common::Base
      include Common::Client::Concerns::ServiceStatus

      attribute :status, Integer

      def initialize(status, attributes = nil)
        super(attributes) if attributes
        self.status = status
      end

      def ok?
        status == 200
      end

      def cache?
        ok?
      end

      def metadata
        { status: response_status }
      end

      def response_status
        case status
        when 200
          RESPONSE_STATUS[:ok]
        when 204
          RESPONSE_STATUS[:no_content]
        when 403
          RESPONSE_STATUS[:not_authorized]
        when 404
          RESPONSE_STATUS[:not_found]
        when 500
          RESPONSE_STATUS[:internal_server_error]
        else
          RESPONSE_STATUS[:server_error]
        end
      end
    end

    class ClaimantStatusResponse < Response
      attribute :claimant_id, Integer
      attribute :delimiting_date, String
      attribute :verified_details, Array
      attribute :payment_on_hold, Boolean

      def initialize(status, response = nil)
        attributes = {
          claimant_id: response.body['claimant_id'],
          delimiting_date: response.body['delimiting_date'],
          verified_details: response.body['verified_details'],
          payment_on_hold: response.body['payment_on_hold']
        }

        super(status, attributes)
      end
    end

    class ClaimantLookupResponse < Response
      attribute :claimant_id, Integer

      def initialize(status, response = nil)
        attributes = { claimant_id: response.body['claimant_id'] }

        super(status, attributes)
      end
    end

    class VerificationRecordResponse < Response
      attribute :claimant_id, Integer
      attribute :delimiting_date, String
      attribute :enrollment_verifications, Array
      attribute :verified_details, Array
      attribute :payment_on_hold, Boolean

      def initialize(status, response = nil)
        attributes = {
          claimant_id: response.body['claimant_id'],
          delimiting_date: response.body['delimiting_date'],
          enrollment_verifications: response.body['enrollment_verifications'],
          verified_details: response.body['verified_details'],
          payment_on_hold: response.body['payment_on_hold']
        }

        super(status, attributes)
      end
    end

    class VerifyClaimantResponse < Response
      attribute :claimant_id, Integer
      attribute :delimiting_date, String
      attribute :verified_details, Array
      attribute :payment_on_hold, Boolean

      def initialize(status, response = nil)
        attributes = {
          claimant_id: response.body['claimant_id'],
          delimiting_date: response.body['delimiting_date'],
          verified_details: response.body['verified_details'],
          payment_on_hold: response.body['payment_on_hold']
        }

        super(status, attributes)
      end
    end
  end
end
