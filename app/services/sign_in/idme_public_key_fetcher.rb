# frozen_string_literal: true

require 'sign_in/idme/errors'

module SignIn
  class IdmePublicKeyFetcher
    def perform
      uri = URI(Settings.idme.oauth_public_key_url)
      response = Net::HTTP.get_response(uri)
      raise StandardError, 'Failed to connect to ID.me public certificates endpoint' unless response.code.to_i == 200

      rs256_keys = JSON.parse(response.body)['keys'].filter_map do |key|
        next unless key['kty'] == 'RSA' && key['algorithm'] == 'RS256'

        JWT::JWK::RSA.import(key).public_key
      end
      return rs256_keys if rs256_keys.present?

      raise StandardError, 'No ID.me RS256 public key found'
    rescue => e
      raise Idme::Errors::PublicKeyError, e&.message
    end
  end
end
