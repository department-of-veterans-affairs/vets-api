# frozen_string_literal: true

class CaseSensitiveString < String
  def downcase
    self
  end

  def capitalize
    self
  end

  def to_s
    self
  end
end

module EVSS
  class AuthHeaders
    def initialize(user)
      @user = user
    end

    def to_h
      @headers ||= {
        CaseSensitiveString.new('va_eauth_csid') => 'DSLogon',
        # TODO: Change va_eauth_authenticationmethod to vets.gov
        # once the EVSS team is ready for us to use it
        CaseSensitiveString.new('va_eauth_authenticationmethod') => 'DSLogon',
        CaseSensitiveString.new('va_eauth_pnidtype') => 'SSN',
        CaseSensitiveString.new('va_eauth_assurancelevel') => @user.loa[:current].to_s,
        CaseSensitiveString.new('va_eauth_firstName') => @user.first_name,
        CaseSensitiveString.new('va_eauth_lastName') => @user.last_name,
        CaseSensitiveString.new('va_eauth_issueinstant') => @user.last_signed_in.iso8601,
        CaseSensitiveString.new('va_eauth_dodedipnid') => @user.edipi,
        CaseSensitiveString.new('va_eauth_pid') => @user.participant_id,
        CaseSensitiveString.new('va_eauth_pnid') => @user.ssn,
        CaseSensitiveString.new('va_eauth_birthdate') => iso8601_birth_date,
        CaseSensitiveString.new('va_eauth_authorization') => eauth_json
      }
    end

    private

    def eauth_json
      {
        authorizationResponse: {
          status: 'VETERAN',
          idType: 'SSN',
          id: @user.ssn,
          edi: @user.edipi,
          firstName: @user.first_name,
          lastName: @user.last_name,
          birthDate: iso8601_birth_date
        }
      }.to_json
    end

    def iso8601_birth_date
      return nil unless @user&.va_profile&.birth_date
      DateTime.parse(@user.va_profile.birth_date).iso8601
    end
  end
end
