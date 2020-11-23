# frozen_string_literal: true

require 'vre/configuration'
require 'common/client/base'

module VRE
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    def get_token
      with_monitoring do
        conn = Faraday.new(
          "#{Settings.veteran_readiness_and_employment.auth_endpoint}?grant_type=client_credentials",
          headers: {'Authorization' => "Basic #{Settings.veteran_readiness_and_employment.credentials}"}
        )

        request = conn.post
        JSON.parse(request.body)['access_token']
      end
    end

    def send_to_vre(payload:)
      with_monitoring do
        perform(
          :post,
          "#{Settings.veteran_readiness_and_employment.base_url}#{Settings.veteran_readiness_and_employment.ch_31_endpoint}",
          payload,
          request_headers
        ) # see lib/common/client/base.rb#L94
      end
    end

    def request_headers
      {
        'Authorization': "Bearer #{get_token}"
      }
    end
  end
end
