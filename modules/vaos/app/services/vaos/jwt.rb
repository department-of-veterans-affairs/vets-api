# frozen_string_literal: true

module VAOS
  class JWT
    def initialize(user)
      @user = user
    end

    def token
      rsa_private = OpenSSL::PKey::RSA.new(cert)
      ::JWT.encode(payload, rsa_private, 'RS512')
    end

    private

    def payload
      now = Time.now
      {
        authenticated: true,
        sub: @user.icn,
        idType: 'ICN',
        iss: 'gov.va.vaos',
        firstName: @user.first_name,
        lastName: @user.last_name,
        authenticationAuthority: 'gov.va.iam.ssoe.v1',
        jti: SecureRandom.uuid,
        nbf: now.utc.to_i - 60,
        exp: now.utc.to_i + 3600,
        version: 1.0,
        userType: 'VETERAN',
        'vamf.auth.roles' => ['veteran']
      }
    end

    def cert
      File.read(Settings.va_mobile.key_path)
    end
  end
end
