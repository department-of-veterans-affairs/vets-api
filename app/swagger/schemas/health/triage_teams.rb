# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class TriageTeams
        include Swagger::Blocks

        swagger_schema :TriageTeams do
          key :required, %i[data meta]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :'$ref', :TriageTeamsBase
            end
          end

          property :meta, '$ref': :MetaSort
        end

        swagger_schema :TriageTeamsBase do
          key :required, %i[id type attributes]

          property :id, type: :string
          property :type, type: :string, enum: [:triage_teams]
          property :attributes, type: :object do
            key :required, %i[triage_team_id name relation_type]

            property :triage_team_id, type: :integer
            property :name, type: :string
            property :relation_type, type: :string
          end
        end
      end
    end
  end
end
