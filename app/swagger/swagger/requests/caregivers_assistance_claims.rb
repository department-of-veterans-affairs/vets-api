# frozen_string_literal: true

module Swagger
  module Requests
    class CaregiversAssistanceClaims
      include Swagger::Blocks

      swagger_path '/v0/caregivers_assistance_claims' do
        operation :post do
          extend Swagger::Responses::ValidationError

          key :description,
              'Submit a 10-10CG form (Application for the Program of Comprehensive Assistance for Family Caregivers)'

          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'The application\'s submission data (formatted in compliance with the 10-10CG schema).'
            key :required, true

            schema do
              key :type, :string
            end
          end

          response 200 do
            key :description, 'Form Submitted'

            schema do
              key :required, [:data]

              property :data, type: :object do
                property :id do
                  key :description, 'Number of pages contained in the form'
                  key :type, :string
                  key :example, ''
                end

                property :type do
                  key :description, 'This is always "form1010cg_submissions"'
                  key :type, :string
                  key :example, 'form1010cg_submissions'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/caregivers_assistance_claims/facilities' do
        operation :post do
          key :description, 'Get a list of medical facilities based on search criteria.'

          key :tags, %w[benefits_forms]

          parameter do
            key :name, :zip
            key :in, :query
            key :description, 'The zip code for facility search.'
            key :type, :string
          end

          parameter do
            key :name, :state
            key :in, :query
            key :description, 'The state for facility search.'
            key :type, :string
          end

          parameter do
            key :name, :lat
            key :in, :query
            key :description, 'The latitude for facility search.'
            key :type, :number
          end

          parameter do
            key :name, :long
            key :in, :query
            key :description, 'The longitude for facility search.'
            key :type, :number
          end

          parameter do
            key :name, :radius
            key :in, :query
            key :description, 'The radius around the location for facility search.'
            key :type, :number
          end

          parameter do
            key :name, :page
            key :in, :query
            key :description, 'The page of results to retrieve.'
            key :type, :integer
          end

          parameter do
            key :name, :per_page
            key :in, :query
            key :description, 'The number of facilities per page.'
            key :type, :integer
          end

          parameter do
            key :name, :facilityIds
            key :in, :query
            key :description, 'Comma-separated list of facility IDs to filter by.'
            key :type, :string
          end

          response 200 do
            key :description, 'List of facilities retrieved successfully'
            schema do
              key :$ref, :Facilities
            end
          end
        end
      end

      swagger_path '/v0/caregivers_assistance_claims/download_pdf' do
        operation :post do
          key :description, 'Download a pre-filled 10-10CG PDF form.'

          key :tags, %w[benefits_forms]

          parameter do
            key :name, :claim_id
            key :in, :query
            key :description, 'The ID of the claim to download the PDF for.'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'PDF form download'

            schema do
              property :data, type: :string, format: 'binary'
            end
          end
        end
      end
    end
  end
end
