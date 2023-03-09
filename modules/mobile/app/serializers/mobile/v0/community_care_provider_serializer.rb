# frozen_string_literal: true

module Mobile
  module V0
    class CommunityCareProviderSerializer
      include JSONAPI::Serializer

      set_id :provider_identifier

      attribute :name do |object|
        possible_name =
          case object.provider_type
          when /GroupPracticeOrAgency/i
            object.care_site
          else
            object.provider_name
          end
        [possible_name, object.name].find(&:present?)
      end

      attribute :address do |object|
        {
          street: object.address_street,
          city: object.address_city,
          state: object.address_state_province,
          zip_code: object.address_postal_code
        }
      end

      attribute :distance, &:miles
    end
  end
end
