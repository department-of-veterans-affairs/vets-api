# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class TriageTeams
        include Swagger::Blocks

        swagger_schema :TriageTeams do
          key :required, [:data, :meta, :links]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :'$ref', :TriageTeamsBase
            end
          end

          property :meta, '$ref': :MetaSortPagination
          property :links, '$ref': :LinksAll
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
end
