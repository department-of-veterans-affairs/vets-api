# frozen_string_literal: true

module Swagger
  module Requests
    class PreneedsClaims
      include Swagger::Blocks

      swagger_schema :PreneedAddress do
        property :street, type: :string, example: '140 Rock Creek Church Rd NW'
        property :street2, type: :string, example: ''
        property :city, type: :string, example: 'Washington'
        property :country, type: :string, example: 'USA'
        property :state, type: :string, example: 'DC'
        property :postalCode, type: :string, example: '20011'
      end

      swagger_schema :PreneedName do
        property :first, type: :string, example: 'Jon'
        property :middle, type: :string, example: 'Bob'
        property :last, type: :string, example: 'Doe'
        property :suffix, type: :string, example: 'Jr.'
        property :maiden, type: :string, example: 'Smith'
      end

      swagger_schema :PreneedCemeteryAttributes do
        property :cemetery_id, type: :string, example: '915', description: 'the same cemetary id again'
        property :cemetery_type, type: :string, example: 'N', enum: %w[N S I A M]
        property :name, type: :string, example: 'ABRAHAM LINCOLN NATIONAL CEMETERY'
        property :num, type: :string, example: '915', description: 'the same cemetary id yet again, why not?'
      end

      swagger_schema :PreneedCemeteries do
        key :required, [:data]

        property :data, type: :array do
          items do
            property :id, type: :string, example: '915', description: 'the cemetary id'
            property :type, type: :string, example: 'preneeds_cemeteries'
            property :attributes, type: :object do
              key :$ref, :PreneedCemeteryAttributes
            end
          end
        end
      end

      swagger_path '/v0/preneeds/cemeteries' do
        operation :get do
          key :description, 'Get the cemeteries from EOAS (Eligibility Office Automation System)'
          key :operationId, 'getCemetaries'
          key :tags, %w[benefits_forms]

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :PreneedCemeteries
            end
          end
        end
      end
    end
  end
end
