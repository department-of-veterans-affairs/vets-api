# frozen_string_literal: true

require 'claims_api/v2/params_validation/veteran_identifier/veteran_info'
require 'claims_api/v2/params_validation/base'

module ClaimsApi
  module V2
    module ParamsValidation
      module VeteranIdentifier
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
