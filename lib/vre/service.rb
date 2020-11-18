# frozen_string_literal: true

module VRE
  class Service
    def get_token
      conn = Faraday.new(
        "#{Settings.vre.auth_endpoint}?grant_type=client_credentials",
        headers: { 'Authorization' => Settings.vre.credentials }
      )

      request = conn.post

      JSON.parse(request.body)['access_token']
    end

    def send_to_vre(payload, exception)
      conn = Faraday.new(url: Settings.vre.base_url)

      response = conn.post do |req|
        req.url Settings.vre.ch_31_endpoint
        req.headers['Authorization'] = "Bearer #{get_token}"
        req.headers['Content-Type'] = 'application/json'
        req.body = payload
      end

      response_body = JSON.parse(response.body)
      return true if response_body['ErrorOccurred'] == false

      raise exception
    rescue exception => e
      log_exception_to_sentry(
        e,
        {
          intake_id: response_body['ApplicationIntake'],
          error_message: response_body['ErrorMessage']
        },
        { team: 'vfs-ebenefits' }
      )
    end
  end
end
