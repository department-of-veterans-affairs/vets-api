# frozen_string_literal: true

module FormEngine
  class Address < VAProfile::Models::V3::Address
    def initialize(params)
      super(params)

      if params[:country_code_iso3].present?
        @country_code_iso2 = IsoCountryCodes.find(params[:country_code_iso3]).alpha2
      end
    end
  end
end
