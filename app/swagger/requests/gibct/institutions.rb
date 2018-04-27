# frozen_string_literal: true

module Swagger
  module Requests
    module Gibct
      class Institutions
        include Swagger::Blocks

        swagger_path '/v0/gi/institutions/autocomplete' do
          operation :get do
            key :description, 'Retrieves institution names begining with a set of letters'
            key :operationId, 'gibctInstitutionsAutocomplete'
            key :tags, %w[gi_bill_institutions]

            parameter name: :term, in: :query,
                      required: true, type: :string, description: 'start of an institution name'

            response 200 do
              key :description, 'autocomplete response'

              schema do
                key :'$ref', :GibctInstitutionsAutocomplete
              end
            end
          end
        end

        swagger_path '/v0/gi/institutions/search' do
          operation :get do
            key :description, 'Retrieves institutions with a partial match for names, or match of city or facility code'
            key :operationId, 'gibctInstitutionsSearch'
            key :tags, %w[gi_bill_institutions]

            parameter name: :term, in: :query,
                      required: false, type: :string, description: '(partial) institution name, city, or facility code'

            response 200 do
              key :description, 'search response'

              schema do
                key :'$ref', :GibctInstitutionsSearch
              end
            end
          end
        end

        swagger_path '/v0/gi/institutions/{id}' do
          operation :get do
            key :description, 'Get details about an institution'
            key :operationId, 'showInstitution'
            key :tags, %w[gi_bill_institutions]

            parameter name: :id, in: :path, required: true, type: :integer,
                      description: 'facility code of the institution'

            response 200 do
              key :description, 'show response'

              schema do
                key :'$ref', :GibctInstitution
              end
            end

            response 404 do
              key :description, 'Operation fails with invalid facility code'

              schema do
                key :'$ref', :Errors
              end
            end
          end
        end
      end
    end
  end
end
