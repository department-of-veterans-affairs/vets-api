# frozen_string_literal: true

module ClaimsApi
  class Veteran
    SSN_REGEX = /\d{3}-\d{2}-\d{4}|\d{9}/

    include Virtus.model
    %i[ssn
       first_name
       middle_name
       last_name
       edipi
       gender
       birls_file_number
       uuid
       pid].each do |attr|
      attribute attr, String
    end

    attribute :loa, Hash
    attribute :va_profile, OpenStruct
    attribute :last_signed_in, Time

    delegate :birls_id, to: :mvi, allow_nil: true
    delegate :participant_id, to: :mvi, allow_nil: true

    def birth_date
      va_profile[:birth_date]
    end

    def valid?(*)
      true
    end

    def loa3?
      true
    end

    def mvi
      @mvi ||= Mvi.for_user(self)
    end

    def ssn=(new_ssn)
      raise Common::Exceptions::ParameterMissing 'X-VA-SSN' unless SSN_REGEX.match(new_ssn)
      super(new_ssn)
    end

    def va_profile=(new_va_profile)
      matches = Date.parse(new_va_profile.birth_date).iso8601
      raise Common::Exceptions::ParameterMissing 'X-VA-Birth-Date' unless matches
      super(new_va_profile)
    end

    def loa3_user
      true
    end

    def authn_context
      'auth'
    end

    def mhv_icn
      nil
    end

    def dslogon_edipi
      edipi
    end

    def self.from_headers(headers, with_gender: false)
      veteran = new(
        uuid: 'something-not-nil',
        ssn: ensure_header(headers, 'X-VA-SSN'),
        first_name: ensure_header(headers, 'X-VA-First-Name'),
        last_name: ensure_header(headers, 'X-VA-Last-Name'),
        va_profile: build_profile(headers),
        edipi: ensure_header(headers, 'X-VA-EDIPI'),
        last_signed_in: Time.now.utc
      )
      veteran.gender = ensure_header(headers, 'X-VA-Gender') if with_gender
      veteran
    end

    def self.build_profile(headers)
      OpenStruct.new(
        birth_date: ensure_header(headers, 'X-VA-Birth-Date')
      )
    end

    def self.ensure_header(headers, key)
      raise Common::Exceptions::ParameterMissing, key unless headers[key]
      headers[key]
    end
  end
end
