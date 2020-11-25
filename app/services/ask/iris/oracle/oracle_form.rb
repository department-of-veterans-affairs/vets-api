# frozen_string_literal: true

module Ask
  module Iris
    module Oracle
      class OracleForm
        attr_reader :fields

        def initialize(form_data)
          @fields = make_field_list
          parse(form_data)
        end

        def self.read_value_for_field(field, value)
          field.schema_key.split('.').each do |key|
            raise "missing path #{field.schema_key}" if value.nil?

            value = value[key]
          end
          value
        end

        private

        def parse(form_data)
          @fields.each do |field|
            field.value = self.class.read_value_for_field(field, form_data)
          end
        end

        def make_field_list
          field_list = FIELD_LIST
          field_list.map do |field_properties|
            Field.new(field_properties)
          end
        end
      end
    end
  end
end
