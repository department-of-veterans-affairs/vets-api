# frozen_string_literal: true

module EVSS
  class AuthHeaders
    def initialize(user)
      @user = user
    end

    def to_h
      @headers ||= {
        'va_eauth_csid' => 'DSLogon',
        # TODO: Change va_eauth_authenticationmethod to vets.gov
        # once the EVSS team is ready for us to use it
        'va_eauth_authenticationmethod' => 'DSLogon',
        'va_eauth_pnidtype' => 'SSN',
        'va_eauth_assurancelevel' => @user.loa[:current].to_s,
        'va_eauth_firstName' => @user.first_name,
        'va_eauth_lastName' => @user.last_name,
        'va_eauth_issueinstant' => @user.last_signed_in.iso8601,
        'va_eauth_dodedipnid' => (@user.edipi || ''),
        'va_eauth_birlsfilenumber' => (@user.birls_id || ''),
        'va_eauth_pid' => @user.participant_id,
        'va_eauth_pnid' => (@user.ssn || ''),
        'va_eauth_birthdate' => iso8601_birth_date,
        'va_eauth_authorization' => eauth_json
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
