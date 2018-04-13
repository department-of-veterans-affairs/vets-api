# frozen_string_literal: true

# frozen_string_literal

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
        raise Common::Exceptions::UnprocessableEntity, error_details('Gender is required & must be "FEMALE" or "MALE"')
      end
    end
  end
end
