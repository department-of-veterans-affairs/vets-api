# frozen_string_literal: true

module VAOS
  class JWT
    def initialize(user)
      @user = user
    end

    def token
      ::JWT.encode(payload, rsa_private, 'RS512')
    end

    private

    def payload
      {
        authenticated: true,
        sub: @user.icn,
        idType: 'ICN',
        iss: 'gov.va.vaos',
        firstName: @user.first_name,
        lastName: @user.last_name,
        authenticationAuthority: 'gov.va.iam.ssoe.v1',
        jti: SecureRandom.uuid,
        nbf: 1.minute.ago.to_i,
        exp: 1.hour.from_now.to_i,
        version: 1.0,
        userType: 'VETERAN',
        'vamf.auth.roles' => ['veteran']
      }
    end

    def rsa_private
      OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
    end
  end
end
