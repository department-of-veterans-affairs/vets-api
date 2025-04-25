# frozen_string_literal: true

require 'common/exceptions'
require 'vets/model'

module ClaimsApi
  class Veteran
    SSN_REGEX = /\d{3}-\d{2}-\d{4}|\d{9}/

    include Vets::Model

    %i[ssn
       first_name
       middle_name
       last_name
       edipi
       participant_id
       gender
       birls_file_number
       icn
       idme_uuid
       logingov_uuid
       uuid
       icn_with_aaid
       search_token
       mhv_icn
       pid].each do |attr|
      attribute attr, String
    end

    # Vets::Model will not work with `default: -> { {} }`
    attribute :loa, Hash, default: {} # rubocop:disable Rails/AttributeDefaultBlockValue
    attribute :va_profile, OpenStruct
    attribute :last_signed_in, Time

    delegate :birls_id, to: :mpi, allow_nil: true
    delegate :participant_id, to: :mpi, allow_nil: true
    delegate :person_types, to: :mpi, allow_nil: true

    def birth_date
      va_profile&.birth_date
    end

    def birth_date=(new_birth_date)
      va_profile&.birth_date = new_birth_date
    end

    def gender_mpi
      mpi_profile&.gender
    end

    def edipi_mpi
      mpi_profile&.edipi
    end

    def participant_id_mpi
      mpi_profile&.participant_id
    end

    def valid?(*)
      va_profile.present?
    end

    def loa3?
      loa[:current] == 3
    end

    def mpi
      @mpi ||= MPIData.for_user(self)
    end

    def recache_mpi_data
      @mpi = MPIData.for_user(self)
    end

    def mpi_record?(user_key: uuid)
      mpi&.mvi_response(user_key:)&.ok?
    end

    def ssn=(new_ssn)
      unless SSN_REGEX.match?(new_ssn)
        raise ::Common::Exceptions::UnprocessableEntity.new(
          detail: 'Invalid SSN in Master Person Index (MPI). ' \
                  'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
        )
      end

      @ssn = new_ssn
    end

    def loa3_user
      loa3?
    end

    def authn_context
      'authn'
    end

    def self.from_identity(identity:)
      new(
        icn: identity.icn,
        uuid: identity.uuid,
        first_name: identity.first_name,
        last_name: identity.last_name,
        last_signed_in: Time.now.utc,
        loa: identity.loa,
        gender: identity.gender,
        mhv_icn: identity.mhv_icn,
        idme_uuid: identity.idme_uuid,
        logingov_uuid: identity.logingov_uuid,
        ssn: identity.ssn,
        va_profile: OpenStruct.new(birth_date: identity.birth_date),
        edipi: identity&.edipi,
        participant_id: identity&.participant_id,
        icn_with_aaid: identity.icn_with_aaid,
        search_token: identity.search_token
      )
    end

    def self.build_profile(birth_date)
      OpenStruct.new(
        birth_date:
      )
    end

    def mpi_icn
      return nil unless mpi

      mpi.icn
    end

    private

    def mpi_profile
      return nil unless mpi

      mpi.profile
    end
  end
end
