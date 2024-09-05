# frozen_string_literal: true

module Veteran
  module Accreditation
    class BaseRepresentativeSerializer
      include JSONAPI::Serializer

      attributes :full_name,
                 :address_line1,
                 :address_line2,
                 :address_line3,
                 :address_type,
                 :city,
                 :country_name,
                 :country_code_iso3,
                 :province,
                 :international_postal_code,
                 :state_code,
                 :zip_code,
                 :zip_suffix,
                 :poa_codes,
                 :phone,
                 :email,
                 :lat,
                 :long,
                 :user_types,
                 :distance

      attribute :distance do |object|
        object.distance / Veteran::Service::Constants::METERS_PER_MILE
      end
    end
  end
end
