module Ask
    module Iris
        module Mappers
            class OracleForm
                attr_reader :fields
        
                def initialize(request)
                  @fields = ToOracle::FIELD_LIST
                  parse(request)
                end
        
                private

                def parse(request)
                  @fields.each do |field|
                    field.value = read_value_for_field(field, request.parsed_form)
                  end
                end
        
                def read_value_for_field(field, value)
                  field.schema_key.split('.').each do |key|
                    value = value[key]
                  end
                  value
                end
              end
        end
    end
end
