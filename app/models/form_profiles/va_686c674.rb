# frozen_string_literal: true

class FormProfiles::VA686c674 < FormProfile
  class FormAddress
    include Virtus.model

    attribute :country_name, String
    attribute :address_line1, String
    attribute :address_line2, String
    attribute :address_line3, String
    attribute :city, String
    attribute :state_code, String
    attribute :province, String
    attribute :zip_code, String
    attribute :international_postal_code, String
  end

  attribute :form_address

  def prefill
    prefill_form_address

    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/686-options-selection'
    }
  end

  private

  def prefill_form_address
    redis_prefill = VAProfileRedis::V2::ContactInformation.for_user(user)

    mailing_address = redis_prefill&.mailing_address if user.icn.present?
    return if mailing_address.blank?

    @form_address = FormAddress.new(
      mailing_address.to_h.slice(
        :address_line1,
        :address_line2,
        :address_line3,
        :city,
        :state_code,
        :province,
        :zip_code,
        :international_postal_code
      ).merge(country_name: mailing_address.country_code_iso3)
    )
  end
end
