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
              property :type, type: :string, example: 'original'
              property :id, type: :string, example: 'abc123'
              property :attributes, type: :object do
                property :appeal_ids do
                  key :type, :array
                  items do
                    key :type, :string
                  end
                end
                property :updated, type: :string, example: '2018-01-19T10:20:42-05:00'
                property :active, type: :boolean, example: false
                property :incomplete_history, type: :boolean, example: false
                property :aoj, type: :string, enum: %w[vba vha nca other], example: 'vba'
                property :program_area, type: :string, enum: %w[
                  compensation pension insurance loan_guaranty education vre medical burial bva other multiple
                ], example: 'compensation'
                property :description, type: :string, example: ''
                property :type, type: :string, enum: %w[
                  original post_remand post_cavc_remand reconsideration cue
                ], example: 'original'
                property :aod, type: :boolean, example: false
                property :location, type: :string, enum: %w[aoj bva], example: 'aoj'
                property :status, type: :object do
                  property :details, type: :object, example: '{}'
                  property :type, type: :string, example: 'ftr'
                end
                property :docket, type: [:object, 'null'], example: {}
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
