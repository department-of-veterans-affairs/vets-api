# frozen_string_literal: true

require 'common/client/base'
require 'dgib/authentication_token_service'
require 'dgib/service'
require 'dgib/verification_record/configuration'
require 'dgib/verification_record/response'

module Vye
  module DGIB
    module VerificationRecord
      class Service < Vye::DGIB::Service
        configuration Vye::DGIB::VerificationRecord::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.verification_record_service'

        def get_verification_record(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            raw_response = perform(:get, end_point(claimant_id), {}, headers, options)
            Vye::DGIB::VerificationRecord::Response.new(raw_response.status, raw_response)
          end
        end

        private

        def end_point(claimant_id)
          "verifications/vye/#{claimant_id}/verification-record"
        end

        def json
          nil
        end

        def request_headers
          {
            Authorization: "Bearer #{DGIB::AuthenticationTokenService.call}"
          }
        end
      end
    end
  end
end
