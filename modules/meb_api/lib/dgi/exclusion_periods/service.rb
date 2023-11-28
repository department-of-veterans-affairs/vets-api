# frozen_string_literal: true

require 'common/client/base'
require 'dgi/exclusion_periods/configuration'
require 'dgi/exclusion_periods/response'
require 'dgi/service'
require 'authentication_token_service'

module MebApi
  module DGI
    module ExclusionPeriod
      class Service < MebApi::DGI::Service
        configuration MebApi::DGI::ExclusionPeriod::Configuration
        STATSD_KEY_PREFIX = 'api.dgi.status'

        def get_exclusion_periods(claimant_id)
          with_monitoring do
            headers = request_headers
            options = { timeout: 60 }
            response = perform(:get, exclusion_periods_url(claimant_id), {}, headers, options)

            MebApi::DGI::ExclusionPeriod::Response.new(response)
          end
        end


        private

        def exclusion_periods_url(claimant_id)
          "/claimant/exclusionperiodtypes/#{claimant_id}"
        end

        def request_headers
          {
            "Content-Type": 'application/json',
            Authorization: "Bearer #{MebApi::AuthenticationTokenService.call}"
          }
        end

        def camelize_keys_for_java_service(params)
          local_params = params[0] || params

          local_params.permit!.to_h.deep_transform_keys do |key|
            if key.include?('_')
              split_keys = key.split('_')
              split_keys.collect { |key_part| split_keys[0] == key_part ? key_part : key_part.capitalize }.join
            else
              key
            end
          end
        end
      end
    end
  end
end
