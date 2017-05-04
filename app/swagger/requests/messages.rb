# frozen_string_literal: true
module Swagger
  module Requests
    class Messages
      include Swagger::Blocks

      swagger_path '/v0/messaging/health/recipients' do
        operation :get do
          key :description, 'Get a list of triageTeams'
          key :operationId, 'triageTeamIndex'
          key :tags, %w(messages)

          parameter name: :page, in: :query, required: false, type: :integer,
                    description: 'Page of results, greater than 0'

          parameter name: :per_page, in: :query, required: false, type: :integer,
                    description: 'number of results, between 1 and 99'

          parameter name: :sort, in: :query, required: false, type: :string,
                    description: "Comma separated sort field(s), prepend field(s) with '-' for descending sort"

          response 200 do
            key :description, 'triage team recipients response'

            schema do
              key :'$ref', :TriageTeamsResponse
            end
          end
        end
      end

      swagger_schema :TriageTeamsResponse do
        key :required, [:data, :meta, :links]
        #
        property :data, type: :array, minItems: 1, uniqueItems: true do
          items do
            key :'$ref', :TriageTeamsBase
          end
        end

        property :meta, type: :object do
          key :required, [:sort, :pagination]

          property :sort, type: :object
          property :pagination, type: :object do
            key :required, [:current_page, :per_page, :total_pages, :total_entries]

            property :current_page, type: :integer
            property :per_page, type: :integer
            property :total_pages, type: :integer
            property :total_entries, type: :integer
          end
        end

        property :links, type: :object do
          key :required, %i(self first prev next last)

          property :self, type: :string
          property :first, type: :string
          property :prev, type: [:string, :null]
          property :next, type: [:string, :null]
          property :last, type: :string
        end
      end

      swagger_schema :TriageTeamsBase do
        key :required, [:id, :type, :attributes]

        property :id, type: :string
        property :type, type: :string, enum: [:triage_teams]
        property :attributes, type: :object do
          key :required, [:triage_team_id, :name, :relation_type]

          property :triage_team_id, type: :integer
          property :name, type: :string
          property :relation_type, type: :string
        end
      end
    end
  end
end
