# frozen_string_literal: true

require 'claims_api/v2/veteran_identifier/params_validation/base'

module ClaimsApi
  module V2
    module VeteranIdentifier
      module ParamsValidation
        class VeteranInfo < Base
          class BirthdateValidator < ActiveModel::EachValidator
            def validate_each(record, attribute, value)
              if value.blank?
                record.errors.add attribute, 'birthdate cannot be blank'
                return
              end

              begin
                date = Date.parse(value)
              rescue ArgumentError
                record.errors.add attribute, 'invalid date'
                return
              end

              record.errors.add attribute, 'birthdate cannot be in the future' if date >= Time.zone.today
            end
          end

          validates_presence_of :firstName, :lastName
          validates :ssn, presence: true, format: { with: /\A\d{9}\z/ }
          validates :birthdate, birthdate: true
        end
      end
    end
  end
end
