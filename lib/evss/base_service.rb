# frozen_string_literal: true
require_dependency 'evss/error_middleware'

module EVSS
  class BaseService
    SYSTEM_NAME = 'vets.gov'

    def initialize(user)
      @user = user
      @default_timeout = 5 # seconds
    end

    protected

    def get(url)
      conn.get url
    end

    def post(url, body = nil, headers = { 'Content-Type' => 'application/json' }, &block)
      conn.post(url, body, headers, &block)
    end

    private

    # Uses HTTPClient adapter because headers need to be sent unmanipulated
    # Net/HTTP capitalizes headers
    def conn
      @conn ||= Faraday.new(@base_url, headers: vaafi_headers) do |faraday|
        faraday.options.timeout = @default_timeout
        faraday.use      EVSS::ErrorMiddleware
        faraday.use      Faraday::Response::RaiseError
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter  :httpclient
      end
    end

    def vaafi_headers
      @vaafi_headers ||= {
        # Always the same
        'va_eauth_csid' => 'DSLogon',
        # TODO: Change va_eauth_authenticationmethod to vets.gov
        # once the EVSS team is ready for us to use it
        'va_eauth_authenticationmethod' => 'DSLogon',
        'va_eauth_assurancelevel' => '2',
        'va_eauth_pnidtype' => 'SSN',
        # Vary by user
        'va_eauth_firstName' => @user.first_name,
        'va_eauth_lastName' => @user.last_name,
        'va_eauth_issueinstant' => @user.issue_instant,
        'va_eauth_dodedipnid' => @user.edipi,
        'va_eauth_pid' => @user.participant_id,
        'va_eauth_pnid' => @user.ssn,
        'va_eauth_authorization' => eauth_json
      }
    end

    def eauth_json
      {
        authorizationResponse: {
          status: 'VETERAN',
          idType: 'SSN',
          id: @user.ssn,
          edi: @user.edipi,
          firstName: @user.first_name,
          lastName: @user.last_name
        }
      }.to_json
    end
  end
end
