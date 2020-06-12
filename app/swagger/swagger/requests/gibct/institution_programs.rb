# frozen_string_literal: true

module Swagger
  module Requests
    module Gibct
      class InstitutionPrograms
        include Swagger::Blocks

        swagger_path '/v0/gi/institution_programs/autocomplete' do
          operation :get do
            key :description, 'Retrieves institution programs beginning with a set of letters'
            key :operationId, 'gibctInstitutionProgramsAutocomplete'
            key :tags, %w[gi_bill_institutions]

            parameter name: :term, in: :query,
                      required: true, type: :string, description: 'start of an institution program name'

            response 200 do
              key :description, 'autocomplete response'

              schema do
                key :'$ref', :GibctInstitutionProgramsAutocomplete
              end
            end
          end
        end

        swagger_path '/v0/gi/institution_programs/search' do
          operation :get do
            key :description, 'Retrieves institution programs with partial match'
            key :operationId, 'gibctInstitutionProgramsSearch'
            key :tags, %w[gi_bill_institutions]

            parameter name: :term,
                      in: :query,
                      required: false,
                      type: :string,
                      description: '(partial) institution program name, city, or facility code'

            response 200 do
              key :description, 'search response'

              schema do
                key :'$ref', :GibctInstitutionProgramsSearch
              end
            end
          end
        end
      end
    end
  end
end
