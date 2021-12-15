# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        class IntentToFileValidator < ActiveModel::Validator
          def validate(record)
            validate_type(record)
            validate_participant_claimant_id(record)
            validate_participant_vet_id(record)
          end

          private

          def validate_type(record)
            value = record.data[:type]
            (record.errors.add :type, 'blank') && return if value.blank?

            record.errors.add :type, value unless %w[compensation pension].include?(value.downcase)
          end

          # 'participant_claimant_id' isn't required, but if it's defined, then it needs a non-blank value
          def validate_participant_claimant_id(record)
            return unless record.data.key?(:participant_claimant_id)

            value = record.data[:participant_claimant_id]
            (record.errors.add :participant_claimant_id, 'blank') && return if value.blank?
          end

          # 'participant_vet_id' isn't required, but if it's defined, then it needs a non-blank value
          def validate_participant_vet_id(record)
            return unless record.data.key?(:participant_vet_id)

            value = record.data[:participant_vet_id]
            (record.errors.add :participant_vet_id, 'blank') && return if value.blank?
          end
        end
      end
    end
  end
end
