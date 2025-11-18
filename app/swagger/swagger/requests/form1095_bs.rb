# frozen_string_literal: true

module Swagger
  module Requests
    class Form1095Bs
      include Swagger::Blocks

      swagger_path '/v0/form1095_bs/available_forms' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'List of available 1095-B forms for the user'
          key :operationId, 'getAvailable1095BForms'
          key :tags, %w[form_1095_b]

          parameter :authorization

          response 200 do
            key :description, 'Successful return of available forms array'
            schema do
              key :required, %i[available_forms]
              property :available_forms, type: :array do
                items do
                  property :year, type: :integer, example: 2021
                  property :last_updated, type: %i[string null], example: '2022-08-03T16:08:50.071Z'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/form1095_bs/download_txt/{tax_year}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Download text version of the 1095-B for the given tax year'
          key :operationId, 'downloadTextForm1095B'
          key :produces, ['text/plain; charset=utf-8']
          key :tags, %w[form_1095_b]

          parameter :authorization

          parameter do
            key :name, :tax_year
            key :in, :path
            key :description, 'Tax year of 1095-B to retrieve'
            key :required, true
            key :type, :integer
          end

          response 200 do
            key :description, 'Successful production of 1095-B text form'
            schema do
              key :type, :file
            end
          end

          response 404 do
            key :description, "User's 1095-B form not found for given tax-year"
            schema do
              key :$ref, :Errors
            end
          end
        end
      end

      swagger_path '/v0/form1095_bs/download_pdf/{tax_year}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Download PDF version of the 1095-B for the given tax year'
          key :operationId, 'downloadPdfForm1095B'
          key :produces, ['application/pdf']
          key :tags, %w[form_1095_b]

          parameter :authorization

          parameter do
            key :name, :tax_year
            key :in, :path
            key :description, 'Tax year of 1095-B to retrieve'
            key :required, true
            key :type, :integer
          end

          response 200 do
            key :description, 'Successful production of 1095-B PDF form'
            schema do
              key :type, :file
            end
          end

          response 404 do
            key :description, "User's 1095-B form not found for given tax-year"
            schema do
              key :$ref, :Errors
            end
          end
        end
      end
    end
  end
end
