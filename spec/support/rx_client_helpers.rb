# frozen_string_literal: true

require 'rx/client'

module Rx
  module ClientHelpers
    HOST = Settings.mhv.rx.host
    CONTENT_TYPE = 'application/json'
    APP_TOKEN = 'your-unique-app-token'
    TOKEN = 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahl7CjswZe8SZGKMUVFIu8='

    def authenticated_client
      Rx::Client.new(session: { user_id: 123,
                                expires_at: Time.current + (60 * 60),
                                token: TOKEN },
                     upstream_request: instance_double(ActionDispatch::Request,
                                                      { 'env' => { 'SOURCE_APP' => 'myapp' } }))
    end

    def stub_varx_request(method, api_endpoint, response_hash, opts = {})
      with_opts = { headers: Rx::Configuration.base_request_headers.merge('Token' => TOKEN) }
      with_opts[:body] = opts[:body] unless opts[:body].nil?
      status_code = opts[:status_code] || 200

      response = response_hash.nil? ? '' : response_hash

      stub_request(method, "#{HOST}/#{api_endpoint}")
        .with(with_opts)
        .to_return(
          status: status_code,
          body: response,
          headers: { 'Content-Type' => CONTENT_TYPE }
        )
    end
  end
end
