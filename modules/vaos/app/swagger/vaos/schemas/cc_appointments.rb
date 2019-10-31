# frozen_string_literal: true

module VAOS
  module Schemas
    class CCAppointments
      include Swagger::Blocks

      swagger_schema :Appointments do
        key :required, %i[data meta]

        property :data, type: :array do
          items do
            key :id, type: :string
            key :type, type: :string, enum: %w[cc_appointments]
            key :attributes, type: :object do
              key :'$ref', :CCAppointment
            end
          end
        end

        property :meta, type: :object do
          key: :'ref', :Pagination
        end
      end

      swagger_schema :CCAppointment do
        key :required, %i[id type attributes]

        property :id, type: :string
        property :type, type: :string, enum: :va_appointments
        property :attributes, type: :object do
          property :appointment_request_id, type: :string
          property :distance_eligible_confirmed, type: :boolean
          property :name, type: :object do
            property :first_name, type: :string
            property :last_name, type: :string
          end
          property :provider_practice, type: :string
          property :provider_phone, type: :string
          property :address, type: :object do
            property :street, type: :string
            property :city, type: :string
            property :state, type: :string
            property :zip_code, type: :string
          end
          property :instructions_to_veteran, type: :string
          property :appointment_time, type: :string
          property :time_zone, type: :string
        end
      end
    end
  end
end
