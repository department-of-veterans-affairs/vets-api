# frozen_string_literal: true

module OpenidAuth
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_content

    def token_payload
      @token_payload ||= if token
                          #  pubkey = expected_key(token)
                          #  return if pubkey.blank?
                           JWT.decode(token, nil, false, algorithm: 'HS256')[0]['validated_token']
                         end
    end

    def validate_token
      raise 'Validation error: issuer' unless token_payload['iss'] == Settings.oidc.issuer
      raise 'Validation error: audience' unless token_payload['aud'] == Settings.oidc.audience
      # raise 'Validation error: ttl' unless token_payload['exp'] >= Time.current.utc.to_i
    end
  end
end
