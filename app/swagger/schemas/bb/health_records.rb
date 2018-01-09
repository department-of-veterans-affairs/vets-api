# frozen_string_literal: true

module Swagger
  module Schemas
    module BB
      class HealthRecords
        include Swagger::Blocks

        swagger_schema :HealthRecordsEligibleDataClasses do
          key :required, [:data, :meta]

          property :data, type: :object do
            key :required, [:id, :type, :attributes]

            property :id, type: :string
            property :type, type: :string, enum: ['eligible_data_classes']
            property :attributes, type: :object do
              key :required, [:data_classes]

              property :data_classes, type: :array, minItems: 1 do
                items do
                  key :type, :string
                end
              end
            end
          end

          property :meta, '$ref': :BbMeta
        end

        swagger_schema :HealthRecordsRefresh do
          key :required, [:data, :meta]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :required, [:id, :type, :attributes]
              property :id, type: :string
              property :type, type: :string, enum: ['extract_statuses']
              property :attributes, type: :object do
                key :required, [:extract_type, :last_updated, :status, :created_on, :station_number]

                property :extract_type, type: :string
                property :last_updated, type: [:null, :string]
                property :status, type: [:null, :string]
                property :created_on, type: [:null, :string]
                property :station_number, type: :string
              end
            end
          end

          property :meta, '$ref': :BbMeta
        end

        swagger_schema :BbMeta do
          key :type, :object
          key :required, [:updated_at, :failed_station_list]

          property :updated_at, type: [:null, :string]
          property :failed_station_list, type: [:null, :string]
        end
      end
    end
  end
end
