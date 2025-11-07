# frozen_string_literal: true

module SignIn
  class UserInfo
    include ActiveModel::Model
    include ActiveModel::Validations

    validates :email, presence: true
    validates :icn, presence: true

    attr_accessor :csp_type,
                  :csp_uuid,
                  :ial,
                  :aal,
                  :email,
                  :full_name,
                  :birth_date,
                  :ssn,
                  :gender,
                  :address,
                  :phone_number,
                  :person_type,
                  :icn,
                  :sec_id,
                  :edipi,
                  :mhv_ien,
                  :cerner_id,
                  :corp_id,
                  :birls

    def initialize(current_user)
      @current_user = current_user
      super(build_attributes_from(current_user))
    end

    def persisted?
      false
    end

    def to_h
      {
        csp_type:,
        csp_uuid:,
        ial:,
        aal:,
        email:,
        full_name:,
        birth_date:,
        ssn:,
        gender:,
        address:,
        phone_number:,
        person_type:,
        icn:,
        sec_id:,
        edipi:,
        mhv_ien:,
        cerner_id:,
        corp_id:,
        birls:
      }.compact
    end

    private

    def build_attributes_from(user)
      {
        csp_type: user.csp_type,
        csp_uuid: user.csp_uuid,
        ial: user.ial,
        aal: user.aal,
        email: user.email,
        full_name: derive_full_name(user),
        birth_date: user.birth_date,
        ssn: normalized_ssn(user.ssn),
        gender: user.gender,
        address: user.address,
        phone_number: user.phone,
        person_type: user.person_type,
        icn: user.icn,
        sec_id: user.sec_id,
        edipi: user.edipi,
        mhv_ien: user.mhv_ien,
        cerner_id: user.cerner_id,
        corp_id: user.corp_id,
        birls: user.birls_id
      }
    end

    def normalized_ssn(ssn)
      ssn&.gsub(/\D/, '')
    end

    def full_name_from(user)
      return user.full_name if user.respond_to?(:full_name) && user.full_name.present?

      [user.try(:first_name), user.try(:middle_name), user.try(:last_name)]
        .compact_blank
        .join(' ')
        .presence
    end
  end
end
