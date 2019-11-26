# frozen_string_literal: true

module VAOS
  class JWT
    VERSION = 2.1
    ISS = 'gov.va.vaos'
    ID_TYPE = 'ICN'
    AUTHORITY = 'gov.va.iam.ssoe.v1'

    attr_reader :user

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
        sub: icn,
        idType: ID_TYPE,
        iss: ISS,
        firstName: first_name,
        lastName: last_name,
        authenticationAuthority: AUTHORITY,
        jti: SecureRandom.uuid,
        nbf: 1.minute.ago.to_i,
        exp: 15.minutes.from_now.to_i,
        sst: 1.minute.ago.to_i + 50,
        version: VERSION,
        gender: gender,
        dob: dob,
        dateOfBirth: dob,
        edipid: edipi,
        ssn: ssn
      }
    end

    def icn
      user.icn
    end

    def first_name
      user.mvi&.profile&.given_names&.first
    end

    def last_name
      user.mvi&.profile&.family_name
    end

    def gender
      type = user.mvi&.profile&.gender
      return '' unless type.is_a?(String)

      case type.upcase[0, 1]
      when 'M'
        'MALE'
      when 'F'
        'FEMALE'
      end
    end

    def dob
      user.mvi&.profile&.birth_date
    end

    def edipi
      user.mvi&.profile&.edipi
    end

    def ssn
      user.mvi&.profile&.ssn
    end

    def rsa_private
      OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
    end
  end
end
