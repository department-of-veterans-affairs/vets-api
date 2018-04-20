# frozen_string_literal: true

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
        property :id, type: :string
        property :creation_date, type: :string
        property :expiration_date, type: :string
        property :participant_id, type: :integer
        property :source, type: :string
        property :status, type: :string, enum: %w[
          active
          claim_recieved
          duplicate
          expired
          incomplete
        ], example: 'active'
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
                key :'$ref', :IntentToFileBase
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_intent_to_file_intent_to_files_responses'
        end
      end

      swagger_schema :IntentToFile do
        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[intent_to_file]
            property :intent_to_file, type: :object do
              key :'$ref', :IntentToFileBase
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_intent_to_file_intent_to_files_responses'
        end
      end
    end
  end
end
