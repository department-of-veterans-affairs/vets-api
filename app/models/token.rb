# frozen_string_literal: true

class Token
  attr_reader :token_string

  def initialize(token_string)
    @token_string = token_string
    validate_token
  end

  def to_s
    @token_string
  end

  def payload
    @payload ||= if @token_string
                   pubkey = public_key

                   JWT.decode(@token_string, pubkey, true, algorithm: 'RS256')[0]
                 end
  rescue JWT::ExpiredSignature => e
    Rails.logger.info(e.message, token: @token_string)
    raise error_klass(e.message)
  rescue JWT::DecodeError => e
    raise error_klass(e.message)
  end

  def public_key
    decoded_token = JWT.decode(@token_string, nil, false, algorithm: 'RS256')
    kid = decoded_token[1]['kid']
    key = OIDC::KeyService.get_key(kid)
    if key.blank?
      Rails.logger.info('Public key not found', kid: kid, exp: decoded_token[0]['exp'])
      raise error_klass("Public key not found for kid specified in token: '#{kid}'")
    end

    key
  rescue JWT::DecodeError => e
    raise error_klass("Unable to determine public key: #{e.message}")
  end

  def validate_token
    raise error_klass('Invalid issuer') unless valid_issuer?
    raise error_klass('Invalid audience') unless valid_audience?
  end

  def valid_issuer?
    payload['iss'] == Settings.oidc.issuer
  end

  def valid_audience?
    payload['aud'] == Settings.oidc.audience
  end

  def identifiers
    # Here the `sub` field is the same value as the `uuid` field from the original upstream ID.me
    # SAML response. We use this as the primary identifier of the user because, despite openid user
    # records being controlled by okta, we want to remain consistent with the va.gov SSO process
    # that consumes the SAML response directly, outside the openid flow.
    # Example of an upstream uuid for the user: cfa32244569841a090ad9d2f0524cf38
    # Example of an okta uid for the user: 00u2p9far4ihDAEX82p7
    @identifiers ||= OpenStruct.new(
      uuid: payload['sub'],
      okta_uid: payload['uid']
    )
  end

  def error_klass(error_detail_string)
    # Errors from the jwt gem (and other dependencies) are reraised with
    # this class so we can exclude them from Sentry without needing to know
    # all the classes used by our dependencies.
    Common::Exceptions::TokenValidationError.new(detail: error_detail_string)
  end
end
