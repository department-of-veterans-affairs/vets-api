# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/request/multipart_request'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'sm/middleware/response/sm_parser'

module MedicalRecords
  ##
  # HTTP client configuration for {MedicalRecords::Client}
  #
  class LighthouseConfiguration < Common::Client::Configuration::REST
    TTL = 300

    def token_aud_url
      'https://deptva-eval.okta.com/oauth2/aus8nm1q0f7VQ0a482p7/v1/token'
    end

    def token_request_url
      Settings.mhv.lighthouse.token_request_url
    end

    def client_id
      Settings.mhv.lighthouse.client_id
    end

    def claims
      {
        'aud' => token_aud_url,
        'iss' => client_id,
        'sub' => client_id,
        'jti' => SecureRandom.uuid,
        iat: Time.now.to_i,
        exp: Time.now.to_i + TTL
      }
    end

    # lib/medical_records/private.pem

    def key
      OpenSSL::PKey::RSA.new(Settings.mhv.lighthouse.private_key)
    end

    def algorithm
      'RS256'
    end

    def launch(icn)
      Base64.encode64({ patient: icn }.to_json)
    end

    def scopes
      'launch system/Patient.read system/AllergyIntolerance.read'
    end

    # Builds a form encoded parameter set that includes the assertion token, scopes, and
    # veteran or 'patient' ICN.
    #
    # @return String the form encoded set of params
    #
    def build(icn)
      hash = {
        grant_type: 'client_credentials',
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        client_assertion: signed_assertion,
        scope: scopes,
        launch: launch(icn)
      }
      URI.encode_www_form(hash)
    end

    def signed_assertion
      JWT.encode(claims, key, algorithm)
    end

    def lighthouse_headers
      {
        accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    end

    def conn
      Faraday.new(url: token_request_url) do |conn|
        conn.use :breakers
        conn.response :betamocks if Settings.mhv.lighthouse.mock

        conn.adapter Faraday.default_adapter
      end
    end

    def post(params, headers = lighthouse_headers)
      conn.post(token_request_url, params, headers)
    end

    def get_token(icn)
      encoded_params = build(icn)
      response = post(encoded_params, lighthouse_headers)
      JSON.parse(response.body)['access_token']
    end
  end
end
