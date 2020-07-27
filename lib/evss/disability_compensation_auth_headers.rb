# frozen_string_literal: true

require 'evss/base_headers'

module EVSS
  class DisabilityCompensationAuthHeaders < EVSS::BaseHeaders
    # :nocov:

    def add_headers(auth_headers)
      auth_headers.merge(
        'va_eauth_authorization' => eauth_json
      )
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
          birthDate: iso8601_birth_date,
          gender: gender
        }
      }.to_json
    end

    def gender
      case @user.gender
      when 'F'
        'FEMALE'
      when 'M'
        'MALE'
      else
        raise Common::Exceptions::UnprocessableEntity,
              detail: 'Gender is required & must be "F" or "M"',
              source: self.class, event_id: Raven.last_event_id
      end
    end

    # :nocov:
  end
end
