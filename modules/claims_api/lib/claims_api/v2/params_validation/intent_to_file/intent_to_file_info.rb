# frozen_string_literal: true

require 'claims_api/v2/params_validation/base'
require 'claims_api/v2/params_validation/intent_to_file/intent_to_file_validator'

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        class IntentToFileInfo < Base
          validates_with IntentToFileValidator
        end
      end
    end
  end
end
