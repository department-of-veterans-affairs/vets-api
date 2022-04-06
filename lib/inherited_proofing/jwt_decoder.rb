# frozen_string_literal: true

require 'jwt'
require 'inherited_proofing/errors'

module InheritedProofing
  class JwtDecoder
    attr_reader :access_token_jwt

    JWT_ENCODE_ALROGITHM = 'RS256'

    def initialize(access_token_jwt:)
      @access_token_jwt = access_token_jwt
    end

    def perform
      access_token = jwt_decode_access_token
      raise Errors::AccessTokenMissingRequiredAttributesError unless access_token.inherited_proofing_auth

      OpenStruct.new({ inherited_proofing_auth: access_token.inherited_proofing_auth })
    end

    private

    def jwt_decode_access_token
      with_validation = true
      decoded_jwt = JWT.decode(
        access_token_jwt,
        public_key,
        with_validation,
        {
          verify_expiration: with_validation,
          algorithm: JWT_ENCODE_ALROGITHM
        }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise Errors::AccessTokenSignatureMismatchError
    rescue JWT::ExpiredSignature
      raise Errors::AccessTokenExpiredError
    rescue JWT::DecodeError
      raise Errors::AccessTokenMalformedJWTError
    end

    def public_key
      OpenSSL::PKey::RSA.new(File.read(Settings.logingov.oauth_public_key))
    end
  end
end
