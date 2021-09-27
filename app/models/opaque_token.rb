# frozen_string_literal: true

class OpaqueToken
  attr_reader :token_string, :payload, :aud, :is_ssoi

  def initialize(token_string, aud)
    @token_string = token_string
    @aud = aud
    @payload = {}
  end

  def to_s
    @token_string
  end

  def opaque?
    true
  end

  def set_payload(payload)
    @payload = payload
  end

  def set_aud(aud)
    @aud = aud
  end

  def set_is_ssoi(is_ssoi)
    @is_ssoi = is_ssoi
  end

  def client_credentials_token?
    false
  end

  def ssoi_token?
    @is_ssoi
  end

  def static?
    payload && payload['static']
  end
end
