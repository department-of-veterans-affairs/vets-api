# frozen_string_literal: true

module Swagger
  module Schemas
    class CCProviders
      include Swagger::Blocks

      swagger_schema :CCProvider do
        key :required, [:data]

        property :data do
          key :'$ref', :CCProviderObject
        end
      end

      swagger_schema :CCProviderObject do
        key :required, %i[id type attributes]

        property :id, type: :string, example: 'ccp_179209'
        property :type, type: :string, example: 'ccp'

        property :attributes, type: :object do
          property :unique_id, type: :string, example: '179209'
          property :name, type: :string, example: 'Example doctor'
          property :address do
            key :'$ref', :CCPAddress
          end
          property :phone, type: :string, example: '(800) 555-1555'
          property :fax, type: :string, example: '(800) 555-1554'
          property :prefContact, type: :string, example: 'any'
          property :accNewPatients, type: :boolean, example: true
          property :gender, type: :string, example: 'female'
          property :specialty do
            key :'$ref', :CCPSpecialtyNames
          end
        end
      end

      swagger_schema :CCPAddress do
        key :type, :object

        property :street, type: :string, example: '123 Fake Street'
        property :city, type: :string, example: 'Anytown'
        property :state, type: :string, example: 'NY'
        property :zip, type: :string, example: '00001'
      end

      swagger_schema :CCPSpecialtyNames do
        key :type, :array
        key :description, 'Formatted list of specialties of a community care provider'

        items do
          key :'$ref', :CCPSpecialtyName
        end
      end

      swagger_schema :CCPSpecialtyName do
        key :type, :string
        key :example, 'Psychoanalyst'
      end

      swagger_schema :CCSpecialties do
        key :required, [:data]
        property :data do
          key :type, :array
          items do
            key :'$ref', :CCSpecialtyObject
          end
        end
      end

      swagger_schema :CCSpecialtyObject do
        property :SpecialtyCode, type: :string, example: '101Y00000X'
        property :Name, type: :string, example: 'Counselor - Addiction (Substance Use Disorder)'
        property :Grouping, type: :string, example: 'Behavioral Health & Social Service Providers'
        property :Classification, type: :string, example: 'Counselor'
        property :Specialization, type: :string, example: 'Addiction (Substance Use Disorder)'
        property :Description, type: :string, example: 'A provider who is trained and educated in behavior health'
      end
    end
  end
end
