# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module PowerOfAttorney
        class PoaSubmissionValidator < ActiveModel::Validator
          def validate(record)
            validate_poa_code(record)
            validate_signatures(record)
          end

          private

          def validate_poa_code(record)
            value = record.data[:serviceOrganization] && record.data[:serviceOrganization][:poaCode]
            record.errors.add :poaCode, 'blank' if value.blank?
          end

          def validate_signatures(record)
            value = record.data[:signatures]

            record.errors.add :signatures, 'blank' if value.blank?

            return if value.blank?

            record.errors.add :signatures, 'blank signatures.veteran' if value[:veteran].blank?
            record.errors.add :signatures, 'blank signatures.representative' if value[:representative].blank?
          end
        end
      end
    end
  end
end
