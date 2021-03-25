# frozen_string_literal: true

require 'vre/configuration'
require 'common/client/base'

# The VRE::Service class is where we keep VRE related endpoint calls and common methods
module VRE
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    # Makes call to VRE and retrieves a token. Token is valid for 3 minutes so we just fire this on every api call
    #
    # @return [Hash] the student's address
    #
    def get_token
      with_monitoring do
        conn = Faraday.new(
          "#{Settings.veteran_readiness_and_employment.auth_endpoint}?grant_type=client_credentials",
          headers: { 'Authorization' => "Basic #{Settings.veteran_readiness_and_employment.credentials}" }
        )

        request = conn.post
        JSON.parse(request.body)['access_token']
      end
    end

    def send_to_vre(payload:)
      with_monitoring do
        perform(
          :post,
          end_point,
          payload,
          request_headers
        ) # see lib/common/client/base.rb#L94
      end
    end

    def request_headers
      {
        Authorization: "Bearer #{get_token}"
      }
    end

    private

    def end_point
      "#{Settings.veteran_readiness_and_employment.base_url}/api/endpoints/vaGov/new_application"
    end
  end
end
