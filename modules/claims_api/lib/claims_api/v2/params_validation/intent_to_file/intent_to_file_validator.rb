# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module IntentToFile
        class IntentToFileValidator < ActiveModel::Validator
          def validate(record)
            validate_type(record)
          end

          private

          def validate_type(record)
            value = if record&.data&.dig('data')
                      record&.data&.dig('data', 'attributes', 'type')
                    else
                      record&.data&.dig('type')
                    end
            (record&.errors&.add :type, 'blank') && return if value.blank?

            unless ClaimsApi::V2::IntentToFile::ITF_TYPES_TO_BGS_TYPES.keys.include?(value.downcase)
              record.errors.add :type, value
            end
          end
        end
      end
    end
  end
end
