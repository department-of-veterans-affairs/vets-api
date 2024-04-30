# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class SuggestedAddress < Common::Resource
      attribute :id, Types::String.optional.default(nil)
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
      attribute :meta do |address|
        {
          address: address.address_meta,
          validation_key: address.validation_key
        }
      end

      def initialize(address)
        
      end
    end
  end
end