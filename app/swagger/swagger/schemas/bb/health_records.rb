# frozen_string_literal: true

module Swagger
  module Schemas
    module BB
      class HealthRecords
        include Swagger::Blocks

        swagger_schema :HealthRecordsEligibleDataClasses do
          key :required, %i[data meta]

          property :data, type: :object do
            key :required, %i[id type attributes]

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
          key :required, %i[data meta]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :required, %i[id type attributes]
              property :id, type: :string
              property :type, type: :string, enum: ['extract_statuses']
              property :attributes, type: :object do
                key :required, %i[extract_type last_updated status created_on station_number]

                property :extract_type, type: :string
                property :last_updated, type: %i[null string]
                property :status, type: %i[null string]
                property :created_on, type: %i[null string]
                property :station_number, type: :string
              end
            end
          end

          property :meta, '$ref': :BbMeta
        end

        swagger_schema :BbMeta do
          key :type, :object
          key :required, %i[updated_at failed_station_list]

          property :updated_at, type: %i[null string]
          property :failed_station_list, type: %i[null string]
        end
      end
    end
  end
end
