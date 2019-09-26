# frozen_string_literal: true

module VAOS
  class JWT
    def initialize(user)
      @user = user
    end

    def token
      rsa_private = OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
      JWT.encode(payload, rsa_private, 'RS512')
    end

    private

    def payload
      {
        sub: @user.icn,
        idType: 'ICN',
        firstName: @user.first_name,
        lastName: @user.last_name,
        iss: "gov.va.api",
        exp: Time.now.utc.to_i + 4 * 3600,
        nbf: Time.now.utc.to_i - 3600,
        jti: Digest::MD5.hexdigest(Time.now.to_s)
      }
    end
  end
end
