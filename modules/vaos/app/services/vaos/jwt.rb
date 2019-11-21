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
        lastName: @user.mvi&.profile&.family_name, # from MVI not SAML assertion
        sub: @user.icn,
        authenticated: true,
        authenticationAuthority: 'gov.va.iam.ssoe.v1',
        idType: 'ICN',
        iss: 'gov.va.vaos',
        'vamf.auth.resources' => [
          "^.*(/)?patient[s]?/EDIPI/#{@user.edipi}(/.*)?$",
          "^.*(/)?patient[s]?/(ICN/)?#{@user.icn}(/.*)?$"
        ],
        version: 2.1,
        firstName: @user.mvi&.profile&.given_names&.first, # from MVI not SAML assertion
        nbf: 1.minute.ago.to_i,
        sst: 1.minute.ago.to_i + 180,
        patient: {
          firstName: @user.mvi&.profile&.given_names&.first,
          lastName: @user.mvi&.profile&.family_name,
          gender: gender(@user.mvi&.profile&.gender),
          dob: @user.mvi&.profile&.birth_date,
          dateOfBirth: @user.mvi&.profile&.birth_date,
          edipid: @user.mvi&.profile&.edipi,
          ssn: @user.mvi&.profile&.ssn
        },
        'vamf.auth.roles' => ['veteran'],
        exp: 14.minutes.from_now.to_i,
        jti: SecureRandom.uuid, # TODO: need to capture this in logs as part of a middleware for each action invoked
        loa: @user.loa[:current]
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
