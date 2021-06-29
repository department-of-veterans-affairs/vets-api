# frozen_string_literal: true

module ClaimsApi
  module V2
    module ParamsValidation
      module VeteranIdentifier
        class VeteranInfoValidator < ActiveModel::Validator
          def validate(record)
            validate_first_name(record)
            validate_last_name(record)
            validate_ssn(record)
            validate_birthdate(record)
          end

          private

          def validate_first_name(record)
            value = record.data[:firstName]
            record.errors.add :firstName, 'blank' if value.blank?
          end

          def validate_last_name(record)
            value = record.data[:lastName]
            record.errors.add :lastName, 'blank' if value.blank?
          end

          def validate_ssn(record)
            value = record.data[:ssn]
            if value.blank?
              record.errors.add :ssn, 'blank'
              return
            end
            record.errors.add :ssn, value unless value =~ /\A\d{9}\z/
          end

          def validate_birthdate(record)
            value = record.data[:birthdate]

            if value.blank?
              record.errors.add :birthdate, 'blank'
              return
            end

            begin
              date = Date.parse(value)
            rescue ArgumentError
              record.errors.add :birthdate, value
              return
            end

            record.errors.add :birthdate, date if date >= Time.zone.today
          end
        end
      end
    end
  end
end
