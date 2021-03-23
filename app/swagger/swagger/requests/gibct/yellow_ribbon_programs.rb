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
            key :tags, %w[gi_bill_institutions]

            parameter description: 'Filter results by the name of a city.',
                      in: :query,
                      name: :city,
                      required: false,
                      type: :string

            parameter description: 'Filter results to only include unlimited contribution amounts.',
                      enum: ['unlimited'],
                      in: :query,
                      name: :contribution_amount,
                      required: false,
                      type: :string

            parameter description: 'Filter results by a country abbreviation (e.g. "usa").',
                      in: :query,
                      name: :country,
                      required: false,
                      type: :string

            parameter description: 'Filter results to only include unlimited eligible students.',
                      enum: ['unlimited'],
                      in: :query,
                      name: :number_of_students,
                      required: false,
                      type: :string

            parameter description: 'The page of results. It must be greater than 0 if used.',
                      in: :query,
                      name: :page,
                      required: false,
                      type: :number

            parameter description: 'Number of results to include per page. It must be greater than 0 if used.',
                      in: :query,
                      name: :per_page,
                      required: false,
                      type: :string

            parameter description: 'Filter results by the name of the Institution.',
                      in: :query,
                      name: :name,
                      required: false,
                      type: :string

            parameter description: 'Sort results by a Yellow Ribbon Program attribute.',
                      enum: %w[city contribution_amount country number_of_students institution state],
                      in: :query,
                      name: :sort_by,
                      required: false,
                      type: :string

            parameter description: 'Sorts results either ascending or descending.',
                      enum: %w[desc asc],
                      in: :query,
                      name: :sort_direction,
                      required: false,
                      type: :string

            parameter description: 'Filter results by a State abbreviation (e.g. "co").',
                      in: :query,
                      name: :state,
                      required: false,
                      type: :string

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
