# frozen_string_literal: true

module SignIn
  class UserInfo
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :sub, :string
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
    attribute :address, :string
    attribute :phone_number, :string
    attribute :person_type, :string
    attribute :icn, :string
    attribute :sec_id, :string
    attribute :edipi, :string
    attribute :mhv_ien, :string
    attribute :cerner_id, :string
    attribute :corp_id, :string
    attribute :birls, :string
    attribute :gcids, :string
    attribute :npi_id, :string

    def self.from_user(user, user_verification: nil)
      new(
        sub: user.uuid,
        email: user_verification&.user_credential_email&.credential_email || user.email,
        npi_id: user.npi_id, full_name: full_name_from(user),
        first_name: user.first_name, last_name: user.last_name,
        csp_type: csp_type_from_mpi(user_verification), csp_uuid: user_verification.credential_identifier,
        ial: ial_level(user_verification), aal: aal_level(user_verification),
        birth_date: user.birth_date, ssn: user.ssn,
        gender: user.gender, address: user.address, phone_number: user.home_phone,
        person_type: user.try(:person_type), icn: user.icn,
        sec_id: user.sec_id, edipi: user.try(:edipi),
        mhv_ien: user.try(:mhv_ien), cerner_id: user.try(:cerner_id),
        corp_id: user.participant_id, birls: user.birls_id, gcids: accepted_gcids(user.mpi_gcids)
      )
    end

    def to_oidc_json
      {
        sub:, first_name:, npi_id:, full_name:,
        last_name:, email:, csp_type:, csp_uuid:,
        ial:, aal:, birth_date:, ssn:,
        gender:, address:, phone_number:, person_type:,
        icn:, sec_id:, edipi:, mhv_ien:,
        cerner_id:, corp_id:, birls:, gcids:
      }
    end

    def to_h
      attributes.deep_symbolize_keys.compact
    end

    def self.full_name_from(user)
      return user.full_name if user.respond_to?(:full_name) && user.full_name.present?

      [user.try(:first_name), user.try(:middle_name), user.try(:last_name)]
        .compact_blank
        .join(' ')
        .presence
    end

    def self.ial_level(user_verification)
      user_verification.verified? ? '2' : '1'
    end

    def self.aal_level(user_verification)
      '2' if %w[idme logingov].include?(user_verification.credential_type)
    end

    def self.csp_type_from_mpi(user_verification)
      case user_verification.credential_type
      when 'idme'
        '200VIDM'
      when 'logingov'
        '200VLGN'
      end
    end

    def gcids=(value)
      super(Array(value).join('|'))
    end

    ACCEPTED_GCID_TYPES = %w[200ENPI 200VETS 200BRLS 200CORP 200VET360 200VIDM 200VLGN 200MHV 200CERNER].freeze

    def self.accepted_gcids(gcids)
      return [] if gcids.blank?

      gcid_list =
        case gcids
        when Array then gcids
        when String then gcids.split('|')
        else []
        end

      gcid_list.select do |gcid|
        _identifier, _code, gcid_type, _agency, _status = gcid.split('^')
        ACCEPTED_GCID_TYPES.include?(gcid_type)
      end
    end
  end
end
