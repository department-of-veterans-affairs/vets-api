# frozen_string_literal: true

module Mobile
  module V0
    class SuggestedAddressSerializer
      include FastJsonapi::ObjectSerializer

      attributes :address_line1
      attributes :address_line2
      attributes :address_line3
      attributes :address_pou
      attributes :address_type
      attributes :city
      attributes :country_code_iso3
      attributes :international_postal_code
      attributes :province
      attributes :state_code
      attributes :zip_code
      attributes :zip_code_suffix

      # rubocop is misinterpreting this, converting to symbol proc will cause specs to fail
      # rubocop:disable Style/SymbolProc
      meta do |address|
        address.meta
      end
      # rubocop:enable Style/SymbolProc
    end
  end
end
