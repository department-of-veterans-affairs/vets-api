# frozen_string_literal: true

module Responses
  class PowerOfAttorneyResponse
    include Swagger::Blocks

    swagger_schema :PowerOfAttorneyResponse do
      key :type, :object

      property :data do
        key :type, :object

        property :id do
          key :type, :string
          key :example, '123456'
        end

        property :type do
          key :type, :string
          key :description, <<-DESC
          Specifies the category of Power of Attorney (POA) representation. This field differentiates between two primary forms of POA:
          - 'veteran_service_representatives': Represents individual representatives who are authorized to act on behalf of veterans. These representatives include attorneys and claim agents.
          - 'veteran_service_organizations': Denotes organizations accredited to provide representation to veterans.
          DESC
          key :enum, %w[veteran_service_representatives veteran_service_organizations]
        end

        property :attributes do
          key :required, %i[type name address_line1 city state_code zip_code]
          key :type, :object

          property :type do
            key :type, :string
            key :description, 'Type of Power of Attorney representation'
            key :example, 'organization'
            key :enum, %w[organization representative]
          end

          property :name do
            key :type, :string
            key :example, 'Veterans Association'
          end

          property :address_line1 do
            key :type, :string
            key :example, '1234 Freedom Blvd'
          end

          property :city do
            key :type, :string
            key :example, 'Arlington'
          end

          property :state_code do
            key :type, :string
            key :example, 'VA'
          end

          property :zip_code do
            key :type, :string
            key :example, '22204'
          end

          property :phone do
            key :type, :string
            key :example, '555-1234'
          end

          property :email do
            key :type, :string
            key :example, 'contact@example.org'
          end
        end
      end
    end
  end
end
