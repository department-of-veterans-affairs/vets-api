# frozen_string_literal: true

require 'claims_api/v2/veteran_identifier/params_validation/veteran_info'

module ClaimsApi
  module V2
    module VeteranIdentifier
      module ParamsValidation
        class Main < Base
          validate :validate_veteran_info

          private

          def validate_veteran_info
            veteran_info_validator = VeteranInfo.new(data)

            return if veteran_info_validator.valid?

            add_nested_errors_for(:veteran_info, veteran_info_validator)
          end
        end
      end
    end
  end
end
