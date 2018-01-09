# frozen_string_literal: true

module Swagger
  module Requests
    module Messages
      class TriageTeams
        include Swagger::Blocks

        swagger_path '/v0/messaging/health/recipients' do
          operation :get do
            key :description, 'Get a list of triageTeams'
            key :operationId, 'triageTeamsIndex'
            key :tags, %w[triage_teams]

            parameter name: :page, in: :query, required: false, type: :integer,
                      description: 'Page of results, greater than 0'

            parameter name: :per_page, in: :query, required: false, type: :integer,
                      description: 'number of results, between 1 and 99'

            parameter name: :sort, in: :query, required: false, type: :string,
                      description: "Comma separated sort field(s), prepend field(s) with '-' for descending sort"

            response 200 do
              key :description, 'triage team recipients response'

              schema do
                key :'$ref', :TriageTeams
              end
            end
          end
        end
      end
    end
  end
end
