# frozen_string_literal: true

require 'claims_api/v2/params_validation/base'
require 'claims_api/v2/params_validation/veteran_identifier/veteran_info_validator'

module ClaimsApi
  module V2
    module ParamsValidation
      module VeteranIdentifier
        class VeteranInfo < Base
          validates_with VeteranInfoValidator
        end
      end
    end
  end
end
