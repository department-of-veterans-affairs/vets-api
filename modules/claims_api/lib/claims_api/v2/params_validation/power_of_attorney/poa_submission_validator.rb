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
            service_org = record.data[:data][:attributes][:serviceOrganization]
            value = service_org && service_org[:poaCode]
            record.errors.add :poaCode, 'blank' if value.blank?
          end

          def validate_signatures(record)
            record.data[:signatures] = { veteran: 'sign_here', representative: 'sign_here' }
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
