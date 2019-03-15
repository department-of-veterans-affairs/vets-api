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
       mhv_icn
       pid].each do |attr|
      attribute attr, String
    end

    attribute :loa, Hash
    attribute :va_profile, OpenStruct
    attribute :last_signed_in, Time

    delegate :birls_id, to: :mvi, allow_nil: true
    delegate :participant_id, to: :mvi, allow_nil: true
    alias_attribute :dslogon_edipi, :edipi

    def birth_date
      va_profile[:birth_date]
    end

    # Virtus doesnt provide a valid? method, but MVI requires it
    def valid?(*)
      true
    end

    def loa3?
      loa[:current] == 3
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
      loa3?
    end

    def authn_context
      'authn'
    end

    def self.from_headers(headers, with_gender: false)
      veteran = new(
        uuid: ensure_header(headers, 'X-VA-SSN'),
        ssn: ensure_header(headers, 'X-VA-SSN'),
        first_name: ensure_header(headers, 'X-VA-First-Name'),
        last_name: ensure_header(headers, 'X-VA-Last-Name'),
        va_profile: build_profile(headers),
        last_signed_in: Time.now.utc
      )
      # commenting this out until the new non-veteran oauth flow is ready to replace this
      # veteran.loa = { current: 3, highest: 3 }
      veteran.gender = ensure_header(headers, 'X-VA-Gender') if with_gender
      veteran.edipi = headers['X-VA-EDIPI'] if headers['X-VA-EDIPI'].present?
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
