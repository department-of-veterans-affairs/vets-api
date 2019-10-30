# frozen_string_literal: true

module VAOS
  module Requests
    class Appointments
      include Swagger::Blocks

      swagger_path '/appointments' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'returns list of online scheduling appointments'
          key :operationId, 'getAppointments'
          key :tags, %w[appointments]

          parameter :authorization

          parameter do
            key :name, :type
            key :in, :query
            key :required, true
            key :type, :string
            key :enum, %w[va cc]
            key :description, <<-TYPE
Type of appointment:
  * `va` - VA Appointments
  * `cc` - ComunityCares Appointments
TYPE
          end

          parameter do
            key :name, :start_date
            key :in, :query
            key :required, true
            key :type, :string
            key :format, :datetime
            key :description, 'a start date for the query'
          end

          parameter do
            key :name, :end_date
            key :in, :query
            key :required, true
            key :type, :string
            key :format, :datetime
            key :description, 'a end date for the query'
          end

          response 200 do
            key :description, 'The list of VA appointments'
            schema do
              key :'$ref', :Appointments
            end
          end

          response 200 do
            key :description, 'The list of CommunityCares appointments'
            schema do
              key :'$ref', :Appointments
            end
          end

          response 401 do
            key :description, 'User is not authenticated (logged in)'
            schema do
              key :'$ref', :Errors
            end
          end

          response 403 do
            key :description, 'Forbidden: user is not authorized for VAOS'
            schema do
              key :'$ref', :Errors
            end
          end

          response 502 do
            key :description, 'Bad Gateway: the upstream VAOS service returned an invalid response (500+)'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
