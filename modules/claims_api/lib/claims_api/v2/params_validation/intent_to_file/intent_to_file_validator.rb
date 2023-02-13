# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        class IntentToFileValidator < ActiveModel::Validator
          def validate(record)
            validate_type(record)
            validate_participant_claimant_id(record)
          end

          private

          def validate_type(record)
            value = record.data[:type]
            (record.errors.add :type, 'blank') && return if value.blank?

            unless ClaimsApi::V2::IntentToFile::ITF_TYPES_TO_BGS_TYPES.keys.include?(value.downcase)
              record.errors.add :type, value
            end
          end

          # 'participant_claimant_id' isn't required, but if it's defined, then it needs a non-blank value
          def validate_participant_claimant_id(record)
            return unless record.data.key?(:participantClaimantId)

            value = record.data[:participantClaimantId]
            (record.errors.add :participantClaimantId, 'blank') && return if value.blank?
          end
        end
      end
    end
  end
end
