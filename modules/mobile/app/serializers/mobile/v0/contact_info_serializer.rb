# frozen_string_literal: true

module Mobile
  module V0
    class ContactInfoSerializer
      include JSONAPI::Serializer

      set_type :contact_info
      attributes :residential_address, :mailing_address, :home_phone, :mobile_phone, :work_phone

      def initialize(user_id, contact_info)
        resource = ContactInfoStruct.new(id: user_id,
                                         residential_address: contact_info&.residential_address,
                                         mailing_address: contact_info&.mailing_address,
                                         home_phone: contact_info&.home_phone,
                                         mobile_phone: contact_info&.mobile_phone,
                                         work_phone: contact_info&.work_phone)

        super(resource)
      end
    end

    ContactInfoStruct = Struct.new(:id, :residential_address, :mailing_address, :home_phone, :mobile_phone, :work_phone)
  end
end
