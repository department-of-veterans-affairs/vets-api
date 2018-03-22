# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Appeals
        include Swagger::Blocks

        swagger_schema :Appeals do
          key :required, [:data]
          property :data do
            items do
              property :type, type: :string, example: 'TODO'
              property :links, type: :object do
                property :self, type: :string, example: 'TODO'
              end
              property :id, type: :string, example: 'TODO'
              property :attributes, type: :object do
                property :appeal_ids do
                  key :type, :array
                  items do
                    key :type, :string
                  end
                end
                property :updated, type: :string, example: 'TODO'
                property :active, type: :boolean, example: 'TODO'
                property :incomplete_history, type: :boolean, example: 'TODO'
                property :aoj, type: :string, enum: %w(vba vha nca other), example: 'TODO'
                property :program_area, type: :string, enum: %w(compensation pension insurance loan_guaranty education vre medical burial bva other multiple ), example: 'TODO'
                property :description, type: :string, example: 'TODO'
                property :type, type: :string, enum: %w(original post_remand post_cavc_remand reconsideration cue), example: 'TODO'
                property :aod, type: :boolean, example: 'TODO'
                property :location, type: :string, enum: %w(aoj bva), example: 'TODO'
                property :status, type: :object do
                  property :details, type: :object, example: 'TODO'
                  property :type, type: :string, example: 'TODO'
                end
                property :docket, type: :object, example: 'TODO'
                property :issues do
                  items do
                    key :type, :array
                    key :'$ref', :Issue
                  end
                end
                property :alerts do
                  items do
                    key :type, :array
                    key :'$ref', :Alert
                  end
                end
                property :events do
                  items do
                    key :type, :array
                    key :'$ref', :Event
                  end
                end
                property :evidence do
                  items do
                    key :type, :array
                    key :'$ref', :Evidence
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
