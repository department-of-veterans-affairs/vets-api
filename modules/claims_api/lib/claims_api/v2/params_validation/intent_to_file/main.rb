# frozen_string_literal: true

require 'claims_api/v2/params_validation/intent_to_file/intent_to_file_info'
require 'claims_api/v2/params_validation/base'

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        class Main < Base
          validate :validate_intent_to_file_info

          private

          def validate_intent_to_file_info
            intent_to_file_info_validator = IntentToFileInfo.new(data)

            return if intent_to_file_info_validator.valid?

            add_nested_errors_for(:intent_to_file_info, intent_to_file_info_validator)
          end
        end
      end
    end
  end
end
