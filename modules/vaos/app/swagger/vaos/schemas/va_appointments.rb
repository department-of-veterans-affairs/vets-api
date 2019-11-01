# frozen_string_literal: true

module VAOS
  module Schemas
    class VAAppointments
      include Swagger::Blocks

      swagger_schema :Appointments do
        key :required, %i[data meta]

        property :data, type: :array, uniqueItems: true do
          items do
            key :'$ref', :VAAppointment
          end
        end

        property :meta, type: :object do
          key :'$ref', :Pagination
        end
      end

      swagger_schema :VAAppointment do
        key :required, %i[id type attributes]

        property :id, type: :string
        property :type, type: :string, enum: :va_appointments
        property :attributes, type: :object do
          property :start_date, type: :string, format: :datetime
          property :clinic_id, type: :string
          property :clinic_friendly_name, type: %i[string null]
          property :facility_id, type: :string
          property :community_care, type: :boolean
          property :vds_appointments, type: :array, uniqueItems: true do
            items do
              property :appointment_length, type: %i[string null]
              property :appointment_time, type: :string, format: :datetime
              property :clinic, type: :object do
                property :name, type: :string
                property :ask_for_check_in, type: :boolean
                property :facility_code, type: :string
              end
              property :type, type: :string
              property :current_status, type: :string
              property :booking_note, type: %i[string null]
            end
          end
        end
      end
    end
  end
end
