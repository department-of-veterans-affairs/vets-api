# frozen_string_literal: true

module Mobile
  module V0
    class ContactInfoSerializer
      include JSONAPI::Serializer

      ADDRESS_KEYS = %i[
        id
        address_line1
        address_line2
        address_line3
        address_pou
        address_type
        city
        country_name
        country_code_iso3
        international_postal_code
        province
        state_code
        zip_code
        zip_code_suffix
      ].freeze

      EMAIL_KEYS = %i[
        id
        email_address
        confirmation_date
        updated_at
      ].freeze

      PHONE_KEYS = %i[
        id
        area_code
        country_code
        extension
        phone_number
        phone_type
      ].freeze

      set_type :contact_info
      attributes :residential_address, :mailing_address, :home_phone, :mobile_phone, :work_phone, :contact_email

      def initialize(user_id, contact_info)
        resource = ContactInfoStruct.new(id: user_id,
                                         residential_address: filter_keys(contact_info&.residential_address,
                                                                          ADDRESS_KEYS),
                                         mailing_address: filter_keys(contact_info&.mailing_address, ADDRESS_KEYS),
                                         home_phone: filter_keys(contact_info&.home_phone, PHONE_KEYS),
                                         mobile_phone: filter_keys(contact_info&.mobile_phone, PHONE_KEYS),
                                         work_phone: filter_keys(contact_info&.work_phone, PHONE_KEYS),
                                         contact_email: filter_keys(contact_info&.email, EMAIL_KEYS))

        super(resource)
      end

      def filter_keys(value, keys)
        value&.to_h&.slice(*keys)
      end
    end

    ContactInfoStruct = Struct.new(:id, :residential_address, :mailing_address, :home_phone, :mobile_phone,
                                   :work_phone, :contact_email)
  end
end
