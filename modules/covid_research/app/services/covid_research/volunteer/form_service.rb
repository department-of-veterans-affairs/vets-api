# frozen_string_literal: true

require 'json_schemer'
require 'vets_json_schema'

module CovidResearch
  module Volunteer
    class FormService
      SCHEMA = 'COVID-VACCINE-TRIAL'

      def valid?(json)
        schema.valid?(json)
      end

      def valid!(json)
        raise SchemaValidationError, submission_errors(json) unless valid?(json)

        valid?(json)
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

      class SchemaValidationError < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
        end
      end
    end
  end
end
