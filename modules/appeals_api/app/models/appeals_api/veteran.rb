# frozen_string_literal: true

module AppealsApi
  class Veteran
    SSN_REGEX = /\d{3}-\d{2}-\d{4}|\d{9}/

    include Virtus.model
    %i[ssn
       first_name
       last_name
       edipi
       birls_id
       participant_id
       birth_date].each do |attr|
      attribute attr, String
    end

    attribute :loa, Hash
    attribute :last_signed_in, Time

    def ssn=(new_ssn)
      raise Common::Exceptions::ParameterMissing 'X-VA-SSN' unless SSN_REGEX.match(new_ssn)
      super(new_ssn)
    end

    def birth_date=(new_birth_date)
      matches = Date.parse(new_birth_date).iso8601
      raise Common::Exceptions::ParameterMissing 'X-VA-Birth-Date' unless matches
      super(new_birth_date)
    end

    def va_profile
      nil
    end
  end
end
