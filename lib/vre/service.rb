# frozen_string_literal: true

require 'vre/configuration'

module VRE
  class Service
    include Common::Client::Concerns::Monitoring
    def get_token
      with_monitoring do
        conn = Faraday.new(
          "#{Settings.veteran_readiness_and_employment.auth_endpoint}?grant_type=client_credentials",
          headers: { 'Authorization' => Settings.veteran_readiness_and_employment.credentials }
        )

        request = conn.post

        JSON.parse(request.body)['access_token']
      end
    end

    def send_to_vre(payload:)
      headers = {
        'Authorization' => "Bearer #{get_token}",
        'Content-Type' => 'application/json'
      }

      with_monitoring do
        perform(
          :post,
          "#{Settings.veteran_readiness_and_employment.base_url}#{Settings.veteran_readiness_and_employment.ch_31_endpoint}",
          payload,
          headers
        ) # see lib/common/client/base.rb#L94
      end
    end

    # def send_to_vre(payload, exception)
    #   with_monitoring do
    #     conn = Faraday.new(url: Settings.veteran_readiness_and_employment.base_url)
    #
    #     response = conn.post do |req|
    #       req.url Settings.veteran_readiness_and_employment.ch_31_endpoint
    #       req.headers['Authorization'] = "Bearer #{get_token}"
    #       req.headers['Content-Type'] = 'application/json'
    #       req.body = payload
    #     end
    #
    #     response_body = JSON.parse(response.body)
    #     return true if response_body['ErrorOccurred'] == false
    #
    #     raise exception
    #   rescue exception => e
    #     log_exception_to_sentry(
    #       e,
    #       {
    #         intake_id: response_body['ApplicationIntake'],
    #         error_message: response_body['ErrorMessage']
    #       },
    #       {team: 'vfs-ebenefits'}
    #     )
    #   end
    # end
  end
end
