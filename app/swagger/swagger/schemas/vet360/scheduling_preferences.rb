# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class SchedulingPreferences
        include Swagger::Blocks

        # GET response schema
        swagger_schema :SchedulingPreferences do
          key :required, [:data]

          property :data, type: :object do
            key :required, %i[id type attributes]
            property :id, type: :string, example: ''
            property :type, type: :string, example: 'scheduling_preferences'
            property :attributes, type: :object do
              key :required, [:preferences]
              property :preferences, type: :array do
                items type: :object do
                  key :required, %i[item_id option_ids]
                  property :item_id, type: :integer, example: 1,
                                     description: 'Scheduling preference item identifier'
                  property :option_ids, type: :array, description: 'Selected options for this preference item' do
                    items type: :integer, example: 5
                  end
                end
              end
            end
          end
        end

        # POST/PUT/DELETE request body schema
        swagger_schema :SchedulingPreferencesRequest do
          key :required, %i[item_id option_ids]
          property :item_id, type: :integer, example: 1, description: 'Scheduling preference item identifier'
          property :option_ids, type: :array, description: 'Options to select for this preference item' do
            items type: :integer, example: 5
          end
        end
      end
    end
  end
end
