# frozen_string_literal: true

class OpaqueToken
  attr_reader :token_string, :payload, :aud

  def initialize(token_string, aud)
    @token_string = token_string
    @aud = aud
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

  def client_credentials_token?
    false
  end

  def ssoi_token?
    false
  end

  def static?
    payload && payload['static']
  end
end
