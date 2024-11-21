# frozen_string_literal: true

require 'common/client/base'
require 'dgib/authentication_token_service'
require 'dgib/service'
require 'dgib/verify_claimant/configuration'
require 'dgib/verify_claimant/response'

module Vye
  module DGIB
    module VerifyClaimant
      class Service < Vye::DGIB::Service
        configuration Vye::DGIB::VerifyClaimant::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.verify_claimant_service'

        # rubocop:disable Metrics/ParameterLists
        def verify_claimant(
          claimant_id,
          verified_period_begin_date,
          verified_period_end_date,
          verified_through_date,
          verification_method,
          response_type
        )

          params = ActionController::Parameters.new({
                                                      claimant_id:,
                                                      verified_period_begin_date:,
                                                      verified_period_end_date:,
                                                      verified_through_date:,
                                                      verification_method:,
                                                      app_communication: { response_type: }
                                                    })

          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:post, end_point, camelize_keys_for_java_service(params).to_json, headers, options)
            Vye::DGIB::VerifyClaimant::Response.new(response.status, response)
          end
        end
        # rubocop:enable Metrics/ParameterLists

        private

        def end_point
          'verifications/vye/verify'
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
