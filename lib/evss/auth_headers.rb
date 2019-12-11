# frozen_string_literal: true

require 'evss/base_headers'

module EVSS
  class AuthHeaders < EVSS::BaseHeaders
    attr_reader :transaction_id

    def initialize(user)
      @transaction_id = create_transaction_id
      super(user)
    end

    def to_h
      @headers ||= sanitize(
        'va_eauth_csid' => 'DSLogon',
        # TODO: Change va_eauth_authenticationmethod to vets.gov
        # once the EVSS team is ready for us to use it
        'va_eauth_authenticationmethod' => 'DSLogon',
        'va_eauth_pnidtype' => 'SSN',
        'va_eauth_assurancelevel' => @user.loa[:current].to_s,
        'va_eauth_firstName' => @user.first_name,
        'va_eauth_lastName' => @user.last_name,
        'va_eauth_issueinstant' => @user.last_signed_in&.iso8601,
        'va_eauth_dodedipnid' => @user.edipi,
        'va_eauth_birlsfilenumber' => @user.birls_id,
        'va_eauth_pid' => @user.participant_id,
        'va_eauth_pnid' => @user.ssn,
        'va_eauth_birthdate' => iso8601_birth_date,
        'va_eauth_authorization' => eauth_json,
        'va_eauth_authenticationauthority' => 'eauth',
        'va_eauth_service_transaction_id' => @transaction_id
      )
    end

    private

    def create_transaction_id
      "vagov-#{SecureRandom.uuid}"
    end

    def sanitize(headers)
      headers.transform_values! do |value|
        value.nil? ? '' : value
      end
    end

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
  end
end
