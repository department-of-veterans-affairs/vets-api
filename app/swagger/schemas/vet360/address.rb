# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Address
        include Swagger::Blocks

        def self.common_address_fields(block, address_type)
          SwaggerHelpers.add_to_required(block, %i[address_line1 city address_type])

          block.property :address_line1,
             type: :string,
             example: '1493 Martin Luther King Rd',
             maxLength: 100
          block.property :address_line2, type: :string, maxLength: 100
          block.property :address_line3, type: :string, maxLength: 100
          block.property :address_pou,
             type: :string,
             enum: ::Vet360::Models::Address::ADDRESS_POUS,
             example: ::Vet360::Models::Address::RESIDENCE
          block.property :address_type,
             type: :string,
             enum: ::Vet360::Models::Address::ADDRESS_TYPES,
             example: address_type
          block.property :city, type: :string, example: 'Fulton', maxLength: 100
          block.property :country_code_iso3,
                   type: :string,
                   example: 'USA',
                   minLength: 3,
                   maxLength: 3
        end

        swagger_schema :Vet360AddressSuggestion do
          key :type, :object
          SwaggerHelpers.add_to_required(self, :country_code_iso3)
          Swagger::Schemas::Vet360::Address.common_address_fields(self, ::Vet360::Models::Address::DOMESTIC)
          property :international_postal_code, type: :string, example: '12345'
          property :province, type: :string
          property :state_code,
                   type: :string,
                   example: 'MS',
                   minLength: 2,
                   maxLength: 2
          property :zip_code,
                   type: :string,
                   example: '38843',
                   minLength: 5,
                   maxLength: 5
          property :zip_code_suffix,
                   type: :string,
                   example: '1234',
                   minLength: 4,
                   maxLength: 4
        end

        [
          ['Domestic', ::Vet360::Models::Address::DOMESTIC],
          ['International', ::Vet360::Models::Address::INTERNATIONAL],
          ['MilitaryOverseas', ::Vet360::Models::Address::MILITARY]
        ].each do |address_type|
          %w[Post Put].each do |req_type|
            swagger_schema "#{req_type}Vet360#{address_type[0]}Address" do
              Swagger::Schemas::Vet360::Address.common_address_fields(self, address_type[1])
              SwaggerHelpers.add_to_required(self, :country_name)

              property :validation_key, type: :integer
              property :country_name,
                     type: :string,
                     example: 'United States',
                     pattern: ::Vet360::Models::Address::VALID_ALPHA_REGEX.inspect

              if req_type == 'Put'
                SwaggerHelpers.add_to_required(self, :id)

                property :id, type: :integer, example: 1
              end

              if %w[Domestic MilitaryOverseas].include?(address_type[0])
                SwaggerHelpers.add_to_required(self, %i[state_code zip_code])

                property :state_code,
                         type: :string,
                         example: 'MS',
                         minLength: 2,
                         maxLength: 2,
                         pattern: ::Vet360::Models::Address::VALID_ALPHA_REGEX.inspect
                property :zip_code,
                         type: :string,
                         example: '38843',
                         maxLength: 5,
                         pattern: ::Vet360::Models::Address::VALID_NUMERIC_REGEX.inspect
              end

              if address_type[0] == 'International'
                SwaggerHelpers.add_to_required(self, :international_postal_code)

                property :international_postal_code, type: :string, example: '12345'
              end
            end
          end
        end
      end
    end
  end
end
