# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module PowerOfAttorney
        class PoaSubmissionValidator < ActiveModel::Validator
          def validate(record)
            validate_poa_code(record)
          end

          private

          def validate_poa_code(record)
            value = record.data[:serviceOrganization][:poaCode]
            record.errors.add :poaCode, 'blank' if value.blank?
          end
        end
      end
    end
  end
end
