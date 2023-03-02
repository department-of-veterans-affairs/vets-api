# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        class IntentToFileValidator < ActiveModel::Validator
          def validate(record)
            validate_type(record)
            validate_ssn_for_survivor(record)
          end

          private

          def validate_type(record)
            value = record.data[:type]
            (record.errors.add :type, 'blank') && return if value.blank?

            unless ClaimsApi::V2::IntentToFile::ITF_TYPES_TO_BGS_TYPES.keys.include?(value.downcase)
              record.errors.add :type, value
            end
          end

          def validate_ssn_for_survivor(record)
            type = record.data[:type]
            if type == 'survivor' && record.data[:action] != 'type'
              value = record.data[:claimantSsn]
              if value.blank?
                error_detail = "claimantSsn parameter cannot be blank for type 'survivor'"
                raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_detail)
              end
            end
          end
        end
      end
    end
  end
end
