# frozen_string_literal: true

module SignIn
  class UserInfo
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Serialization

    ACCEPTED_GCID_TYPES = %w[
      200ENPI 200VETS 200BRLS 200CORP 200VET360
      200VIDM 200VLGN 200MHV 200CERNER
    ].freeze

    attribute :sub, :string
    attribute :person_types, :string
    attribute :email, :string
    attribute :full_name, :string
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :csp_type, :string
    attribute :csp_uuid, :string
    attribute :ial, :string
    attribute :aal, :string
    attribute :birth_date, :string
    attribute :ssn, :string
    attribute :gender, :string
    attribute :address_street1, :string
    attribute :address_street2, :string
    attribute :address_city, :string
    attribute :address_state, :string
    attribute :address_country, :string
    attribute :address_postal_code, :string
    attribute :phone_number, :string
    attribute :icn, :string
    attribute :sec_id, :string
    attribute :edipi, :string
    attribute :mhv_ien, :string
    attribute :cerner_id, :string
    attribute :corp_id, :string
    attribute :birls, :string
    attribute :gcids, :string
    attribute :npi_id, :string

    class << self
      def from_user(user)
        new(
          sub: user.uuid, person_types: user.person_types.join('|'),
          email: user.user_verification&.user_credential_email&.credential_email,
          npi_id: user.npi_id, full_name: full_name(user),
          first_name: user.first_name, last_name: user.last_name,
          csp_type: csp_type_from_mpi(user), csp_uuid: user.user_verification.credential_identifier,
          ial: ial_level(user), aal: AAL::LOGIN_GOV_AAL2,
          birth_date: user.birth_date, ssn: user.ssn,
          gender: user.gender,
          address_street1: user.address[:street], address_street2: user.address[:street2],
          address_city: user.address[:city], address_state: user.address[:state],
          address_country: user.address[:country], address_postal_code: user.address[:postal_code],
          phone_number: user.home_phone, icn: user.icn,
          sec_id: user.sec_id, edipi: user.try(:edipi),
          mhv_ien: user.try(:mhv_ien), cerner_id: user.try(:cerner_id),
          corp_id: user.participant_id, birls: user.birls_id, gcids: validate_and_parse_gcids(user.mpi_gcids)
        )
      end

      private

      def ial_level(user)
        user.user_verification.verified? ? Constants::Auth::IAL_TWO : Constants::Auth::IAL_ONE
      end

      def csp_type_from_mpi(user)
        case user.user_verification.credential_type
        when 'idme'
          MPI::Constants::IDME_IDENTIFIER
        when 'logingov'
          MPI::Constants::LOGINGOV_IDENTIFIER
        end
      end

      def validate_and_parse_gcids(gcids)
        return nil if gcids.blank?

        gcid_list =
          case gcids
          when Array then gcids
          when String then gcids.split('|')
          else []
          end

        filtered = gcid_list.select do |gcid|
          _identifier, _code, gcid_type, _agency, _status = gcid.split('^')
          ACCEPTED_GCID_TYPES.include?(gcid_type)
        end

        return nil if filtered.empty?

        filtered.join('|')
      end

      def full_name(user)
        user.full_name_normalized.values.compact.join(' ')
      end
    end
  end
end
