# frozen_string_literal: true

require 'common/exceptions'

module ClaimsApi
  class Veteran
    SSN_REGEX = /\d{3}-\d{2}-\d{4}|\d{9}/.freeze

    include Virtus.model

    %i[ssn
       first_name
       middle_name
       last_name
       edipi
       participant_id
       gender
       birls_file_number
       uuid
       mhv_icn
       pid].each do |attr|
      attribute attr, String
    end

    attribute :loa, Hash
    attribute :va_profile, OpenStruct
    attribute :last_signed_in, Time

    delegate :birls_id, to: :mvi, allow_nil: true
    delegate :participant_id, to: :mvi, allow_nil: true

    alias dslogon_edipi edipi

    def birth_date
      va_profile[:birth_date]
    end

    # Virtus doesnt provide a valid? method, but MVI requires it
    def valid?(*)
      va_profile.present?
    end

    def loa3?
      loa[:current] == 3
    end

    def mvi
      @mvi ||= MPIData.for_user(self)
    end

    def mvi_record?
      mvi.mvi_response.ok?
    end

    def ssn=(new_ssn)
      raise Common::Exceptions::ParameterMissing, 'X-VA-SSN' unless SSN_REGEX.match?(new_ssn)

      super(new_ssn)
    end

    def va_profile=(new_va_profile)
      matches = Date.parse(new_va_profile.birth_date).iso8601
      raise Common::Exceptions::ParameterMissing, 'X-VA-Birth-Date' unless matches

      super(new_va_profile)
    end

    def loa3_user
      loa3?
    end

    def authn_context
      'authn'
    end

    def self.from_identity(identity:)
      new(
        uuid: identity.uuid,
        ssn: identity.ssn,
        first_name: identity.first_name,
        last_name: identity.last_name,
        va_profile: OpenStruct.new(birth_date: identity.birth_date),
        last_signed_in: Time.now.utc,
        loa: identity.loa,
        gender: identity.gender,
        edipi: identity.edipi,
        participant_id: identity.participant_id
      )
    end

    def self.build_profile(birth_date)
      OpenStruct.new(
        birth_date: birth_date
      )
    end
  end
end
