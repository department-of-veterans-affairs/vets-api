# frozen_string_literal: true

require 'common/client/base'
require 'post911_sob/dgib/configuration'
require 'post911_sob/dgib/authentication_token_service'
require 'post911_sob/dgib/response'

module Post911SOB
  module DGIB
    class Client < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration Post911SOB::DGIB::Configuration

      BENEFIT_TYPE = 'Chapter33'

      def initialize(claimant_id)
        @claimant_id = claimant_id

        super()
      end

      def get_entitlement_transferred_out
        # TO-DO add monitoring and serialized response
        options = { timeout: 60 }
        raw_response = perform(:get, end_point, {}, request_headers, options)
        Post911SOB::DGIB::Response.new(raw_response)
      end

      private

      def end_point
        "transferees/#{@claimant_id}/toe"
      end

      def request_headers
        {
          Authorization: "Bearer #{Post911SOB::DGIB::AuthenticationTokenService.call}"
        }
      end
    end
  end
end
