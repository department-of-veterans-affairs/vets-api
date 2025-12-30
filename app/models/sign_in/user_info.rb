# frozen_string_literal: true

module SignIn
  class UserInfo
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Serialization

    GCID_TYPE_CODES = {
      icn: '200M',
      sec_id: '200PROV',
      edipi: '200DOD',
      mhv_ien: '200MHV',
      npi_id: '200ENPI',
      vhic_id: '200VHIC',
      nwhin_id: '200NWS',
      cerner_id: '200CRNR',
      corp_id: '200CORP',
      birls_id: '200BRLS',
      salesforce_id: '200DSLF',
      usaccess_piv: '200PUSA',
      piv_id: '200PIV',
      va_active_directory_id: '200AD',
      usa_staff_id: '200USAF'
    }.freeze
    ALLOWED_GCID_CODES = GCID_TYPE_CODES.values.index_with(&:itself).freeze
    NUMERIC_GCID_CODE = /\A\d+\z/

    attribute :sub, :string
    attribute :csp_type, :string
    attribute :ial, :string
    attribute :aal, :string
    attribute :csp_uuid, :string
    attribute :email, :string
    attribute :full_name, :string
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
    attribute :person_types, :string
    attribute :icn, :string
    attribute :sec_id, :string
    attribute :edipi, :string
    attribute :mhv_ien, :string
    attribute :npi_id, :string
    attribute :cerner_id, :string
    attribute :corp_id, :string
    attribute :birls, :string
    attribute :gcids, :string

    validate :gcids_have_approved_identifier

    private

    def gcids_have_approved_identifier
      value = gcids
      return if value.blank?

      segments = value.split('|')

      invalid = segments.reject do |segment|
        next false if segment.blank?

        code = segment.to_s.split('^', 4)[2]
        next false if code.blank?

        ALLOWED_GCID_CODES.key?(code) || code.match?(NUMERIC_GCID_CODE)
      end

      return if invalid.empty?

      errors.add(:gcids, 'contains non-approved gcids')
    end
  end
end
