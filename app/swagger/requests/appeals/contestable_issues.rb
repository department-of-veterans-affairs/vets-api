# frozen_string_literal: true

module Swagger
  module Requests
    module Appeals
      class ContestableIssues
        include Swagger::Blocks

        swagger_path '/services/appeals/v0/appeals/contestable_issues' do
          operation :get do
            key :description, 'Returns a list of contestable issues for veteran'
            key :operationId, 'getContestableIssues'
            key :tags, %w[contestable_issues]

            response 200 do
              key :description, '200 Returns a list of contestable issues'
              schema do
                key :'$ref', :ContestableIssues
              end
            end
          end
        end
      end
    end
  end
end