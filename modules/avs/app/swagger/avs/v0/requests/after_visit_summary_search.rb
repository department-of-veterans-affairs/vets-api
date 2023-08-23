# frozen_string_literal: true

module Avs
  class V0::Requests::AfterVisitSummarySearch
    include Swagger::Blocks

    swagger_path '/avs/v0/avs/search' do
      operation :get do
        extend Swagger::Responses::AuthenticationError

        key :description, 'Returns the path for the After Visit Summary matching the given parameters if any is found.'

        parameter :authorization

        parameter do
          key :name, :stationNo
          key :description, 'VistA Station Number'
          key :in, :query
          key :type, :string
          key :required, true
        end
        parameter do
          key :name, :appointmentIen
          key :description, 'VistA Appointment IEN'
          key :in, :query
          key :type, :string
          key :required, true
        end
        response 200 do
          key :description, 'Response is OK'
          schema do
            key :$ref, :AvsSearchResult
          end
        end
        response 400 do
          key :description, 'Invalid parameters'
          schema do
            key :$ref, :Error
          end
        end
      end
    end
  end
end
