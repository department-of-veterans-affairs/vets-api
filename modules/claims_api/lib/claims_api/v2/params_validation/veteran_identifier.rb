# frozen_string_literal: true

require 'claims_api/v2/params_validation/veteran_identifier/main'

module ClaimsApi
  module V2
    module ParamsValidation
      module VeteranIdentifier
        def self.validator(params)
          VeteranIdentifier::Main.new(params)
        end
      end
    end
  end
end
