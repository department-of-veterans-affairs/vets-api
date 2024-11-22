# frozen_string_literal: true

require 'common/client/base'
require 'post911_sob/dgib/configuration'
require 'post911_sob/dgib/authentication_token_service'

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
        # TO-DO Filter response by chapter33 benefit type
        options = { timeout: 60 }
        perform(:get, end_point, {}, request_headers, options)
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
