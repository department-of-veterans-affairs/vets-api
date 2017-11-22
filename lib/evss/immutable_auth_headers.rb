# frozen_string_literal: true
module EVSS
  class ImmutableAuthHeaders
    def initialize(user)
      @user = user
    end

    def to_h
      return nil unless @user
      headers = Net::HTTP::ImmutableKeysHash.new
      headers['va_eauth_csid'] = 'DSLogon'
      headers['va_eauth_authenticationmethod'] = 'DSLogon'
      headers['va_eauth_pnidtype'] = 'SSN'
      headers['va_eauth_assurancelevel'] = @user.loa[:current].to_s
      headers['va_eauth_firstName'] = @user.first_name
      headers['va_eauth_lastName'] = @user.last_name
      headers['va_eauth_issueinstant'] = @user.last_signed_in.iso8601
      headers['va_eauth_birlsfilenumber'] = @user.birls_id if @user.birls_id
      headers['va_eauth_dodedipnid'] = @user.edipi
      headers['va_eauth_pid'] = @user.participant_id
      headers['va_eauth_pnid'] = @user.ssn
      headers['va_eauth_birthdate'] = iso8601_birth_date
      headers['va_eauth_authorization'] = eauth_json
      headers
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
