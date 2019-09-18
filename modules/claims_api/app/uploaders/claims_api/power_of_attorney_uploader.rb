# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyUploader < ClaimsApi::BaseUploader
    def location
      'power_of_attorney'
    end
  end
end
