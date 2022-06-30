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
            example JSON.parse(File.read('spec/fixtures/notice_of_disagreements/valid_NOD_create_request_V1.json'))
          end

          VetsJsonSchema::SCHEMAS.fetch('NOD-SHOW-RESPONSE-200_V1')['definitions'].each do |k, v|
            swagger_schema(k == 'root' ? 'nodShowRoot' : k, v) {}
          end

          swagger_schema 'nodShowRoot' do
            example JSON.parse(File.read('spec/fixtures/notice_of_disagreements/NOD_show_response_200_V1.json'))
          end

          swagger_schema 'nodContestableIssues' do
            example JSON.parse(
              File.read(
                'spec/fixtures/notice_of_disagreements/NOD_contestable_issues_response_200_V1.json'
              )
            )
          end
        end
      end
    end
  end
end
