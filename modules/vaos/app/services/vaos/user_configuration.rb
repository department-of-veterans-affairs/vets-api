# frozen_string_literal: true

module VAOS
  class UserConfiguration < Configuration
    def connection
      Faraday.new(base_path, headers: headers, request: request_options) do |conn|
        conn.use :breakers

        if ENV['VAOS_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new(STDOUT), :warn)
          conn.response(:logger, ::Logger.new(STDOUT), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :vaos_errors
        conn.adapter Faraday.default_adapter
      end
    end

    private

    def headers
      { 'Content-Type' => 'text/plain', 'Referer' => 'https://api.va.gov' }
    end
  end
end
