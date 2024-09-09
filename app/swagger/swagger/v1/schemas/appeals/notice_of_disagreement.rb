# frozen_string_literal: true

require 'decision_review/schemas'
module Swagger
  module V1
    module Schemas
      module Appeals
        class NoticeOfDisagreement
          include Swagger::Blocks

          VetsJsonSchema::SCHEMAS.fetch('NOD-CREATE-REQUEST-BODY_V1')['definitions'].each do |k, v|
            if k == 'nodCreate'
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

          swagger_schema 'nodCreate' do
            example VetsJsonSchema::EXAMPLES.fetch('NOD-CREATE-REQUEST-BODY_V1')
          end

          VetsJsonSchema::SCHEMAS.fetch('NOD-SHOW-RESPONSE-200_V2')['definitions'].each do |key, value|
            swagger_schema(key == 'root' ? 'nodShowRoot' : key, value) {}
          end

          swagger_schema 'nodShowRoot' do
            example VetsJsonSchema::EXAMPLES.fetch('NOD-SHOW-RESPONSE-200_V2')
          end

          swagger_schema 'nodContestableIssues' do
            example VetsJsonSchema::EXAMPLES.fetch('DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1')
          end
        end
      end
    end
  end
end
