# frozen_string_literal: true

require 'decision_review/schemas'
module Swagger
  module Schemas
    module Appeals
      class NoticeOfDisagreement
        include Swagger::Blocks

        DecisionReview::Schemas::NOD_CREATE_REQUEST['definitions'].each do |k, v|
          # removed values that Swagger 2.0 doesn't recognize
          value = v.except('if', 'then', '$comment')
          swagger_schema k, value
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

        swagger_schema(
          'nodContestableIssues',
          DecisionReview::Schemas::NOD_CONTESTABLE_ISSUES_RESPONSE_200.merge(
            example: JSON.parse(
              File.read('spec/fixtures/notice_of_disagreements/NOD_contestable_issues_response_200.json')
            )
          ).except('$schema')
        )
      end
    end
  end
end
