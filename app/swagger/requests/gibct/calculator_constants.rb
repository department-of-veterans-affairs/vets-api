# frozen_string_literal: true

module Swagger
  module Requests
    module Gibct
      class CalculatorConstants
        include Swagger::Blocks

        swagger_path '/v0/gi/calculator_constants' do
          operation :get do
            key :description, 'Gets all calculator constants'
            key :operationId, 'gibctCalculatorConstantsIndex'
            key :tags, %w[calculator constants index]

            response 200 do
              key :description, 'autocomplete response'

              schema do
                key :'$ref', :GibctCalculatorConstants
              end
            end
          end
        end
      end
    end
  end
end
