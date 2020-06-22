# frozen_string_literal: true

module Swagger
  module Schemas
    class TermsAndConditions
      include Swagger::Blocks

      swagger_schema :TermsAndConditions do
        key :required, [:data]

        property :data, type: :array
        items do
          key :'$ref', :TermsAndConditionsBody
        end
      end

      swagger_schema :TermsAndConditionsSingle do
        key :required, [:data]

        property :data, type: :object
      end

      swagger_schema :TermsAndConditionsBody do
        key :required, %i[id type attributes]

        property :id, type: :string
        property :type, type: :string

        property :attributes, type: :object do
          property :name, type: :string
          property :title, type: :string
          property :header_content, type: :string
          property :terms_content, type: :string
          property :yes_content, type: :string
          property :no_content, type: :string
          property :footer_content, type: :string
          property :version, type: :string
          property :created_at, type: :string, format: :date
          property :updated_at, type: :string, format: :date
        end
      end

      swagger_schema :TermsAndConditionsAcceptance do
        key :required, [:data]

        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string

          property :attributes, type: :object do
            property :created_at, type: :string, format: :date
          end
        end
      end
    end
  end
end
