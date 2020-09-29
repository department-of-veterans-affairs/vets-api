# frozen_string_literal: true

require 'ihub/models/appointment'

module Swagger
  module Requests
    class Appointments
      include Swagger::Blocks

      swagger_path '/v0/appointments' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'List of user appointments for the previous three months, through the upcoming six months'
          key :operationId, 'getAppointments'
          key :tags, %w[
            appointments
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:data]

              property :data, type: :object do
                key :required, [:attributes]
                property :attributes, type: :object do
                  key :required, [:appointments]
                  property :appointments do
                    key :type, :array
                    items do
                      property :appointment_status_code, type: :string
                      property :appointment_status_name, type: :string
                      property :assigning_facility, type: :string
                      property :clinic_code, type: :string, example: '409'
                      property :clinic_name, type: :string, example: 'ZZCHY WID BACK'
                      property :facility_name, type: :string, example: 'CHEYENNE VAMC'
                      property :facility_code, type: :string, example: '442'
                      property :local_id,
                               type: :string,
                               example: '2960112.0812',
                               description: 'The LocalID element is an internal ID from the VistA/Source system'
                      property :other_information, type: :string
                      property :start_time,
                               type: :string,
                               example: '1996-01-12T08:12:00',
                               description: 'Time is in the same timezone that the associated facility_name is in.'
                      property :status_code, type: :string, example: '2'
                      property :status_name,
                               type: :string,
                               example: 'CHECKED OUT',
                               enum: IHub::Models::Appointment::STATUS_NAMES
                      property :type_code, type: :string, example: '9'
                      property :type_name,
                               type: :string,
                               example: 'REGULAR',
                               enum: IHub::Models::Appointment::TYPE_NAMES
                    end
                  end
                end
              end
            end
          end

          response 400 do
            key :description, 'Error Occurred'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'Error Occurred'
                  property :detail,
                           type: :string,
                           example: 'General error received from iHub.  Check sentry logs for details.'
                  property :code, type: :string, example: 'IHUB_101'
                  property :status, type: :string, example: '400'
                  property :source, type: :string, example: 'IHub::Appointments::Service'
                end
              end
            end
          end

          response 502 do
            key :description, 'User missing ICN'
            schema do
              key :required, [:errors]

              property :errors do
                key :type, :array
                items do
                  key :required, %i[title detail code status source]
                  property :title, type: :string, example: 'User missing ICN'
                  property :detail,
                           type: :string,
                           example: 'The user does not have an ICN.'
                  property :code, type: :string, example: 'IHUB_102'
                  property :status, type: :string, example: '502'
                  property :source, type: :string, example: 'IHub::Appointments::Service'
                end
              end
            end
          end
        end
      end
    end
  end
end
