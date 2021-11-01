# frozen_string_literal: true

require 'claims_api/v2/params_validation/power_of_attorney/main'

module ClaimsApi
  module V2
    module ParamsValidation
      module PowerOfAttorney
        def self.validator(params)
          PowerOfAttorney::Main.new(params)
        end
      end
    end
  end
end
