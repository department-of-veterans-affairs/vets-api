# frozen_string_literal: true

require 'claims_api/v2/params_validation/intent_to_file/main'

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        def self.validator(params)
          IntentToFile::Main.new(params)
        end
      end
    end
  end
end
