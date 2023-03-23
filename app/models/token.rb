# frozen_string_literal: true

class Token
  attr_reader :token_string, :aud

  def initialize(token_string, aud)
    @token_string = token_string
    @aud = aud
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
    iss = decoded_token[0]['iss']
    kid = decoded_token[1]['kid']
    key = OIDC::KeyService.get_key(kid, iss)
    if key.blank?
      StatsD.increment('okta_kid_lookup_failure', 1, tags: ["kid:#{kid}"])
      Rails.logger.info('Public key not found', kid:, exp: decoded_token[0]['exp'])
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
    decoded_token = JWT.decode(@token_string, nil, false, algorithm: 'RS256')
    iss = decoded_token[0]['iss']
    !iss.nil? && iss.match?(%r{^#{Regexp.escape(Settings.oidc.issuer_prefix)}/\w+$})
  rescue JWT::DecodeError => e
    raise error_klass(e.message)
  end

  def valid_audience?
    if @aud.nil?
      payload['aud'] == Settings.oidc.isolated_audience.default
    else
      # Temorarily accept the default audience or the API specificed audience
      [Settings.oidc.isolated_audience.default, *@aud].include?(payload['aud'])
    end
  end

  def client_credentials_token?
    payload['sub'] == payload['cid']
  end

  def opaque?
    false
  end

  def ssoi_token?
    payload['last_login_type'] == 'ssoi'
  end

  def static?
    false
  end

  def identifiers
    # Here the `sub` field is the same value as the `login` field from the okta profile.
    # In cases of direct saml-proxy integration with the IDP, the `sub` is
    # the same value as the `uuid` field from the original upstream ID.me
    # However in cases of SSOe, the `sub` is actually the `ICN` for the user
    # We use this as the primary identifier of the user because, despite openid user
    # records being controlled by okta, we want to remain consistent with the va.gov SSO process
    # that consumes the SAML response directly, outside the openid flow.
    # Example of an upstream uuid for the user: cfa32244569841a090ad9d2f0524cf38
    # Example of an okta uid for the user: 00u2p9far4ihDAEX82p7
    # Example of sub for SSOe: 1013062086V794840
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
