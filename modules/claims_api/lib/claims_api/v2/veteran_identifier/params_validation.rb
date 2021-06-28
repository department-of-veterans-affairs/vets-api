# frozen_string_literal: true

require 'claims_api/v2/veteran_identifier/params_validation/main'

module ClaimsApi
  module V2
    module VeteranIdentifier
      module ParamsValidation
        def self.validator(params)
          Main.new(params)
        end
      end
    end
  end
end
