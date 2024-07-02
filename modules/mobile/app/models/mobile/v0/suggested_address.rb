# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class SuggestedAddress < Common::Resource
      attribute :id, Types::String
      attribute :address_line1, Types::String.optional.default(nil)
      attribute :address_line2, Types::String.optional.default(nil)
      attribute :address_line3, Types::String.optional.default(nil)
      attribute :address_pou, Types::String.optional.default(nil)
      attribute :address_type, Types::String.optional.default(nil)
      attribute :city, Types::String.optional.default(nil)
      attribute :country_code_iso3, Types::String.optional.default(nil)
      attribute :international_postal_code, Types::String.optional.default(nil)
      attribute :province, Types::String.optional.default(nil)
      attribute :state_code, Types::String.optional.default(nil)
      attribute :zip_code, Types::String.optional.default(nil)
      attribute :zip_code_suffix, Types::String.optional.default(nil)
      attribute :validation_key, Types::Integer.optional.default(nil)
      attribute :address_meta do
        attribute :confidence_score, Types::Float.optional.default(nil)
        attribute :address_type, Types::String.optional.default(nil)
        attribute :delivery_point_validation, Types::String.optional.default(nil)
      end
    end
  end
end
