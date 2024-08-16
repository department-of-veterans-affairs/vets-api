# frozen_string_literal: true

module Swagger
  module V1
    module Schemas
      module Appeals
        class HigherLevelReview
          include Swagger::Blocks

          VetsJsonSchema::SCHEMAS.fetch('HLR-CREATE-REQUEST-BODY_V1')['definitions'].each do |k, v|
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

            if k == 'hlrCreate'
              # remove draft-07 specific schema items, they won't validate with swagger
              attrs = v['properties']['data']['properties']['attributes']
              attrs['properties']['veteran']['properties']['timezone'].delete('$comment')
              attrs['properties']['veteran'].delete('if')
              attrs['properties']['veteran'].delete('then')
              attrs.delete('if')
              attrs.delete('then')
            end

            swagger_schema k, v
          end

          swagger_schema 'hlrCreate' do
            example VetsJsonSchema::EXAMPLES.fetch 'HLR-CREATE-REQUEST-BODY_V1'
          end

          VetsJsonSchema::SCHEMAS.fetch('HLR-SHOW-RESPONSE-200_V2')['definitions'].each do |key, value|
            value.delete('$comment')
            swagger_schema(key == 'root' ? 'hlrShowRoot' : key, value) {}
          end

          swagger_schema 'hlrShowRoot' do
            example VetsJsonSchema::EXAMPLES.fetch 'HLR-SHOW-RESPONSE-200_V2'
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
              VetsJsonSchema::SCHEMAS.fetch('DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1')
            ).merge(
              description: 'Fields may either be null or the type specified',
              # eventually there should be a generic contestable issues response
              example: VetsJsonSchema::EXAMPLES.fetch('DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1')
            ).except('$schema')
          )
        end
      end
    end
  end
end
