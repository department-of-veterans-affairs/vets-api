# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module EvidenceWaiverSubmission
        class EvidenceWaiverSubmissionValidator < ActiveModel::Validator
          def validate(record)
            validate_tracked_items(record)
          end

          private

          def validate_tracked_items(record)
            if record.data[:data].present?
              value = if record.data[:data]
                        record.data[:data][:attributes][:trackedItemIds]
                      else
                        record.data[:tracked_items]
                      end
              (record.errors.add :tracked_items, 'blank') && return if value.blank?
            end
          end
        end
      end
    end
  end
end
