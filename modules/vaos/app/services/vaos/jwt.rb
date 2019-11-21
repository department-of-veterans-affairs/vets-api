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
        firstName: @user.first_name, # from SAML assertion unless MHV sign in user (MVI).
        lastName: @user.last_name, # from SAML assertion unless MHV sign in user (MVI)
        authenticationAuthority: 'gov.va.iam.ssoe.v1',
        jti: SecureRandom.uuid, # TODO: need to capture this in logs as part of a middleware for each action invoked
        nbf: 1.minute.ago.to_i,
        exp: 1.hour.from_now.to_i,
        patient: {
          firstName: @user.mvi&.profile&.given_names&.first,
          lastName: @user.mvi&.profile&.family_name,
          gender: gender(@user.mvi&.profile&.gender),
          dob: @user.mvi&.profile&.birth_date,
          dateOfBirth: @user.mvi&.profile&.birth_date,
          edipid: @user.mvi&.profile&.edipi,
          ssn: @user.mvi&.profile&.ssn,
        },
        version: 1.0,
        userType: 'VETERAN',
        'vamf.auth.roles' => ['veteran']
      }
    end

    def gender(type)
      return '' unless type.is_a?(String)
      case type.upcase[0,1]
      when 'M'
        'MALE'
      when 'F'
        'FEMALE'
      end
    end

    def rsa_private
      OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
    end
  end
end
