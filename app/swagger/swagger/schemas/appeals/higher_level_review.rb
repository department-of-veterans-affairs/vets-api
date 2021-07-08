# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class HigherLevelReview
        include Swagger::Blocks

        VetsJsonSchema::SCHEMAS.fetch('HLR-CREATE-REQUEST-BODY')['definitions'].each do |k, v|
          v.delete('$comment')
          if k == 'hlrCreateDataAttributes'
            v['oneOf'][1].delete('$comment')
            schema = { description: v['description'] }.merge v['oneOf'][1]

            swagger_schema 'hlrCreateDataAttributes', schema
            next
          end

          if k == 'hlrCreateVeteran'
            v['properties']['timezone'].delete('$comment')
            swagger_schema 'hlrCreateVeteran', v
            next
          end

          swagger_schema k, v
        end
        swagger_schema 'hlrCreate' do
          example VetsJsonSchema::EXAMPLES.fetch 'HLR-CREATE-REQUEST-BODY'
        end

        VetsJsonSchema::SCHEMAS.fetch('HLR-SHOW-RESPONSE-200')['definitions'].each do |k, v|
          v.delete('$comment')
          swagger_schema(k == 'root' ? 'hlrShowRoot' : k, v) {}
        end
        swagger_schema 'hlrShowRoot' do
          example VetsJsonSchema::EXAMPLES.fetch 'HLR-SHOW-RESPONSE-200'
        end

        # recursive
        def self.remove_null_from_type_array(value)
          case value
          when Hash
            value.reduce({}) do |new_hash, (k, v)|
              next new_hash.merge(k => x_from_nullable_x_type(v)) if k == 'type' && type_is_nullable?(v)

              new_hash.merge(k => remove_null_from_type_array(v))
            end
          when Array
            value.map { |v| remove_null_from_type_array(v) }
          else
            value
          end
        end

        def self.x_from_nullable_x_type(type_array)
          nulls_index = type_array.index('null')
          types_index = nulls_index.zero? ? 1 : 0
          type_array[types_index]
        end

        def self.type_is_nullable?(type)
          type.is_a?(Array) && type.length == 2 && type.include?('null')
        end

        swagger_schema(
          'hlrContestableIssues',
          remove_null_from_type_array(
            VetsJsonSchema::SCHEMAS.fetch('HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200')
          ).merge(
            description: 'Fields may either be null or the type specified',
            example: VetsJsonSchema::EXAMPLES.fetch('HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200')
          ).except('$schema')
        )
      end
    end
  end
end
