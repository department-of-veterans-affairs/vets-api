# frozen_string_literal: true

require 'va_profile/models/address'

module FormEngine
  class Address < VAProfile::Models::Address
    def initialize(params)
      super(params)

      if params[:country_code_iso3].present?
        @country_code_iso2 = IsoCountryCodes.find(params[:country_code_iso3]).alpha2
      end
    end
  end
end
