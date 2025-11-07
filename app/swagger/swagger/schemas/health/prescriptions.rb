# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Prescriptions
        include Swagger::Blocks

        swagger_schema :Prescriptions do
          key :required, %i[data meta]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :$ref, :PrescriptionBase
            end
          end

          property :meta do
            key :$ref, :MetaFailedStationListSortPagination
          end

          property :links do
            key :$ref, :LinksAll
          end
        end

        swagger_schema :Prescription do
          key :required, %i[data meta]

          property :data, type: :object do
            key :$ref, :PrescriptionBase
          end

          property :meta do
            key :$ref, :MetaFailedStationList
          end
        end

        swagger_schema :PrescriptionBase do
          key :required, %i[id type attributes links]

          property :id, type: :string
          property :type, type: :string, enum: [:prescriptions]
          property :attributes, type: :object do
            key :required, %i[
              prescription_id prescription_number prescription_name refill_status refill_submit_date
              refill_date refill_remaining facility_name ordered_date quantity expiration_date
              dispensed_date station_number is_refillable is_trackable
            ]

            property :prescription_id, type: :integer
            property :prescription_number, type: :string
            property :prescription_name, type: :string
            property :prescription_image, type: :string
            property :refill_status, type: :string
            property :refill_submit_date, type: %i[string null], format: :date
            property :refill_date, type: :string, format: :date
            property :refill_remaining, type: :integer
            property :facility_name, type: :string
            property :ordered_date, type: :string, format: :date
            property :quantity, type: :string
            property :expiration_date, type: :string, format: :date
            property :dispensed_date, type: %i[string null], format: :date
            property :sorted_dispensed_date, type: %i[string null], format: :date
            property :station_number, type: :string
            property :is_refillable, type: :boolean
            property :is_trackable, type: :boolean
          end
          property :links do
            key :$ref, :LinksSelf
          end
        end
      end
    end
  end
end
