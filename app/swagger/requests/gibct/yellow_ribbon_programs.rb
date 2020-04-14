# frozen_string_literal: true

module Swagger
  module Requests
    module Gibct
      class YellowRibbonPrograms
        include Swagger::Blocks

        swagger_path '/v0/gi/yellow_ribbon_programs' do
          operation :get do
            key :description, 'Retrieves Yellow Ribbon Programs with partial match'
            key :operationId, 'gibctYellowRibbonPrograms'

            parameter name: :term,
                      in: :query,
                      required: false,
                      type: :string,
                      description: '(partial) Yellow Ribbon Program name.'

            response 200 do
              key :description, 'response'

              schema do
                key :'$ref', :GibctYellowRibbonPrograms
              end
            end
          end
        end
      end
    end
  end
end
