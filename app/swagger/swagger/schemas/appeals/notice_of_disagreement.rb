# frozen_string_literal: true

require 'decision_review/schemas'
module Swagger
  module Schemas
    module Appeals
      class NoticeOfDisagreement
        include Swagger::Blocks

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
