# frozen_string_literal: true

module ClaimsApi
  class Veteran
    SSN_REGEX = /\d{3}-\d{2}-\d{4}|\d{9}/

    include Virtus.model
    %i[ssn
       first_name
       last_name
       edipi
       birls_id
       participant_id].each do |attr|
      attribute attr, String
    end

    attribute :loa, Hash
    attribute :va_profile, OpenStruct
    attribute :last_signed_in, Time

    def ssn=(new_ssn)
      raise Common::Exceptions::ParameterMissing 'X-VA-SSN' unless SSN_REGEX.match(new_ssn)
      super(new_ssn)
    end

    def va_profile=(new_va_profile)
      matches = Date.parse(new_va_profile.birth_date).iso8601
      raise Common::Exceptions::ParameterMissing 'X-VA-Birth-Date' unless matches
      super(new_va_profile)
    end
  end
end
