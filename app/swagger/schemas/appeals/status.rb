# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Status
        include Swagger::Blocks

        swagger_schema :Status do
          key :required, [:data]
          property :data do
            items do
              property :id, type: :string, example: 'TODO'
              property :type, type: :string, enum: %w(appeals_status_models_appeals), example: 'TODO'
              property :attributes, type: :object do
                key :required, [:active, :type, :prior_decision_date, :requested_hearing_type, :events, :hearings]
                property :active, type: :boolean, example: 'TODO'
                property :type, type: :string, example: 'TODO'
                property :prior_decision_date, type: :string, example: 'TODO'
                property :requested_hearing_type, type: :string, example: 'TODO'
                property :events do
                  items do
                    property :type, type: :string, example: 'TODO'
                    property :date, type: :string, example: 'TODO'
                  end
                end
                property :hearings do
                  items do
                    property :id, type: :integer, example: 'TODO'
                    property :type, type: :string, example: 'TODO'
                    property :date, type: :string, example: 'TODO'
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
