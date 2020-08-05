# frozen_string_literal: true

require 'json_schemer'
require 'vets_json_schema'

module CovidVaccineTrial
  module Screener
    class FormService
      SCHEMA = 'COVID-VACCINE-TRIAL'

      def valid_submission?(json)
        schema.valid?(json)
      end

      def submission_errors(json)
        schema.validate(json).map do |e|
          if e['data_pointer'].blank?
            {
              detail: e['details']
            }
          else
            {
              source: {
                pointer: e['data_pointer']
              }
            }
          end
        end
      end

      private

      def schema
        @schema ||= JSONSchemer.schema(schema_data)
      end

      def schema_data
        VetsJsonSchema::SCHEMAS[SCHEMA]
      end
    end
  end
end