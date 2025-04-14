# frozen_string_literal: true

require 'disability_compensation/responses/intent_to_files_response'

module Swagger
  module Schemas
    class IntentToFile
      include Swagger::Blocks

      swagger_schema :IntentToFileBase do
        key :required, %i[
          id
          creation_date
          expiration_date
          participant_id
          source
          status
          type
        ]
        property :id, type: :string, example: '1'
        property :creation_date, type: :string, example: '2018-01-21T19:53:45.810+00:00'
        property :expiration_date, type: :string, example: '2018-02-21T19:53:45.810+00:00'
        property :participant_id, type: :integer, example: 1
        property :source, type: :string, example: 'EBN'
        property :status, type: :string, enum: DisabilityCompensation::ApiProvider::IntentToFile::STATUS_TYPES,
                          example: 'active'
        property :type, type: :string, enum: %w[
          compensation
          pension
          survivor
        ], example: 'compensation'
      end

      swagger_schema :IntentToFiles do
        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[intent_to_file]
            property :intent_to_file do
              key :type, :array
              items do
                key :$ref, :IntentToFileBase
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'intent_to_file'
        end
      end

      swagger_schema :IntentToFile do
        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[intent_to_file]
            property :intent_to_file, type: :object do
              key :$ref, :IntentToFileBase
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'intent_to_file'
        end
      end
    end
  end
end
