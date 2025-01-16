# frozen_string_literal: true

# app/controllers/v0/claim_letters_controller.rb
module Swagger
  module Requests
    class ClaimLetters < ApplicationController
      include Swagger::Blocks

      swagger_path '/v0/claim_letters' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of claim letters\' metadata'
          key :tags, %w[claim_letters]
          key :operationId, 'getClaimLetters'
          key :summary, 'Retrieve all claim letters\' metadata'

          response 200 do
            key :description, 'Claim Letters metadata list'

            schema do
              key :type, :array

              items do
                key :$ref, :ClaimLetter
              end
            end
          end
        end
      end

      swagger_path '/v0/claim_letters/{document_id}' do
        operation :get do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::InternalServerError

          key :tags, %w[claim_letters]
          key :summary, 'Download a single PDF claim letter'
          key :operationId, 'downloadPDFClaimLetter'
          key :produces, ['application/pdf']

          parameter do
            key :in, :path
            key :name, :document_id
            key :pattern, '^{[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}}$'
            key :description, 'Specifies the `document_id` (a UUID) of the claim letter to retrieve.\
            Format: ***{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}***. *Note the use of `{` and `}`. These are required.*'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Single Claim Letter PDF'
            schema do
              key :type, :file
            end
          end
        end
      end

      swagger_schema :ClaimLetter do
        property :document_id do
          key :type, :string
          key :pattern, '^{[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}}$'
        end
        property :series_id do
          key :type, :string
          key :pattern, '^{[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}}$'
        end
        property :version, type: :string
        property :type_description, type: :string
        property :type_id, type: :string
        property :doc_type, type: :string
        property :subject, type: %i[string null]
        property :received_at, type: :string
        property :source, type: :string
        property :mime_type, type: :string
        property :alt_doc_types, type: :string
        property :restricted, type: :boolean
        property :upload_date, type: :string
      end
    end
  end
end
