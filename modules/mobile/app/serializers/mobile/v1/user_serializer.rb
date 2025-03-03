# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V1
    class UserSerializer < Mobile::V0::UserSerializer
      include JSONAPI::Serializer

      private

      def profile
        {
          first_name: user.first_name,
          preferred_name: user_demographics.demographics&.preferred_name&.text,
          middle_name: user.middle_name,
          last_name: user.last_name,
          contact_email: filter_keys(contact_info&.email, EMAIL_KEYS),
          signin_email: user.email,
          birth_date: user.birth_date.nil? ? nil : Date.parse(user.birth_date).iso8601,
          gender_identity: nil,
          residential_address: filter_keys(contact_info&.residential_address, ADDRESS_KEYS),
          mailing_address: filter_keys(contact_info&.mailing_address, ADDRESS_KEYS),
          home_phone_number: filter_keys(contact_info&.home_phone, PHONE_KEYS),
          mobile_phone_number: filter_keys(contact_info&.mobile_phone, PHONE_KEYS),
          work_phone_number: filter_keys(contact_info&.work_phone, PHONE_KEYS),
          signin_service: user.identity.sign_in[:service_name].remove('oauth_')
        }
      end
    end
  end
end
