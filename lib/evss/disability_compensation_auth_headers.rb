# frozen_string_literal: true

module EVSS
  class DisabilityCompensationAuthHeaders
    def self.add_headers(auth_headers, user)
      disability_headers = auth_headers.merge('va_eauth_gender' => gender(user))
      Rails.logger.info disability_headers: disability_headers
      disability_headers
    end

    def self.gender(user)
      Rails.logger.info disability_gender: user.gender
      case user.gender
      when 'F'
        'FEMALE'
      when 'M'
        'MALE'
      else
        raise Common::Exceptions::UnprocessableEntity,
              detail: 'Gender is required & must be "FEMALE" or "MALE"',
              source: self.class, event_id: Raven.last_event_id
      end
    end
  end
end
