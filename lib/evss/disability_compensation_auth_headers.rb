# frozen_string_literal: true

module EVSS
  class DisabilityCompensationAuthHeaders
    def self.add_headers(auth_headers, user)
      auth_headers.merge('gender': gender(user))
    end

    def self.gender(user)
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
