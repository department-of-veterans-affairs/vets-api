# frozen_string_literal: true

require 'decision_review/schemas'
module Swagger
  module Schemas
    module Appeals
      class NoticeOfDisagreement
        include Swagger::Blocks

        DecisionReview::Schemas::NOD_CREATE_REQUEST['definitions'].each do |k, v|
          # removed values that Swagger 2.0 doesn't recognize
          swagger_schema k, v.except('if', 'then', '$comment')
        end

        swagger_schema 'nodCreateRoot' do
          example JSON.parse(File.read('spec/fixtures/notice_of_disagreements/valid_NOD_create_request.json'))
        end

        DecisionReview::Schemas::NOD_SHOW_RESPONSE_200['definitions'].each do |k, v|
          swagger_schema(k == 'root' ? 'nodShowRoot' : k, v) {}
        end

        swagger_schema 'nodShowRoot' do
          example JSON.parse(File.read('spec/fixtures/notice_of_disagreements/NOD_show_response_200.json'))
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
          'nodContestableIssues',
          remove_null_from_type_array(
            DecisionReview::Schemas::NOD_CONTESTABLE_ISSUES_RESPONSE_200
          ).merge(
            description: 'Fields may either be null or the type specified',
            example: JSON.parse(
              File.read('spec/fixtures/notice_of_disagreements/NOD_contestable_issues_response_200.json')
            )
          ).except('$schema')
        )
      end
    end
  end
end
