# frozen_string_literal: true

module Ask
  module Iris
    module Oracle
      class OracleForm
        attr_reader :fields

        def initialize(request)
          @fields = make_field_list
          parse(request)
        end

        private

        def parse(request)
          @fields.each do |field|
            field.value = read_value_for_field(field, request.parsed_form)
          end
        end

        def make_field_list
          field_list = FIELD_LIST
          field_list.map do |field_properties|
            Field.new(field_properties)
          end
        end

        def read_value_for_field(field, value)
          field.schema_key.split('.').each do |key|
            raise "missing path #{field.schema_key}" if value.nil?

            value = value[key]
          end
          value
        end
      end
    end
  end
end
