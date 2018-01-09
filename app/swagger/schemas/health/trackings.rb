# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Trackings
        include Swagger::Blocks

        swagger_schema :Trackings do
          key :required, %i[data meta links]

          property :data, type: :array, minItems: 1, uniqueItems: true do
            items do
              key :'$ref', :Tracking
            end
          end

          property :meta do
            key :'$ref', :MetaFailedStationListSortPagination
          end

          property :links do
            key :'$ref', :LinksAll
          end
        end

        swagger_schema :Tracking do
          key :required, %i[id type attributes links]

          property :id, type: :string
          property :type, type: :string, enum: [:trackings]

          property :attributes, type: :object do
            key :'$ref', :TrackingBase
          end

          property :links, type: :object do
            key :'$ref', :LinksTracking
          end
        end

        swagger_schema :TrackingBase do
          key :required, %i[
tracking_number prescription_id prescription_number prescription_name
facility_name rx_info_phone_number ndc_number shipped_date delivery_service]

          property :tracking_number, type: :string
          property :prescription_id, type: :integer
          property :prescription_number, type: :string
          property :prescription_name, type: :string
          property :facility_name, type: :string
          property :rx_info_phone_number, type: :string
          property :ndc_number, type: :string
          property :shipped_date, type: :string, format: :date
          property :delivery_service, type: :string
          property :other_prescriptions, type: :array do
            items do
              key :'$ref', :OtherPrescription
            end
          end
        end

        swagger_schema :OtherPrescription do
          key :required, %i[prescription_name prescription_number ndc_number station_number]

          property :prescription_name, type: :string
          property :prescription_number, type: :string
          property :ndc_number, type: :string
          property :station_number, type: :string
        end
      end
    end
  end
end
